import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../screens/site_map_screen.dart';
import '../services/database_service.dart';
import '../services/report_local_service.dart';
import '../services/sync_service.dart';
import 'report_thumbnail.dart';
import 'timeline_audio_player.dart';

// ---------------------------------------------------------------------------
// The one place a report is shown and discussed.
//
// Before this widget the report was rendered twice with two different levels of
// detail: the full `ReportDetailScreen` (photo, timeline, gate buttons) and the
// Owner's `OwnerActionSheet` (photo, TL badge, decision buttons). Everything
// that both of them duplicated now lives here, so a list tile, a map marker and
// any dashboard can open the exact same sheet through
// [showReportDetailSheet] — and role-specific actions are injected instead of
// being re-implemented.
// ---------------------------------------------------------------------------

/// The five validation states the product talks about, resolved once from the
/// two independent layers (the Team Leader gate and the Owner decision).
///
/// This is the single source of truth for "where is this report right now?" —
/// the sheet renders it as a badge today, and the History stepper (Step 3)
/// renders the same value as three nodes.
enum ReportStage {
  pendingTl,
  rejectedByTl,
  validatedByTl,
  pendingOwner,
  closedByOwner,
}

/// Owner statuses that mean the owner is done with the report.
const Set<String> _closedOwnerStatuses = {
  'validated',
  'approved',
  'acknowledged',
  'ordered',
  'rejected',
};

/// True when the Owner has taken a final decision. The owner layer is the last
/// word of the workflow: once closed, a report stops being actionable even if
/// the Team Leader had rejected it earlier in the timeline.
bool isReportClosedByOwner(Report report) =>
    _closedOwnerStatuses.contains(report.ownerStatus);

/// Resolves the report's current stage.
///
/// A closed report is closed (the owner's decision overrides everything), then
/// a Team Leader rejection short-circuits (the report is back with the
/// subcontractor), then the TL gate decides. Reports that never pass the gate
/// ('problem' reports) go straight to the owner layer.
ReportStage reportStageOf(Report report) {
  if (isReportClosedByOwner(report)) return ReportStage.closedByOwner;
  if (report.isTlRejected) return ReportStage.rejectedByTl;
  final ownerClosed = isReportClosedByOwner(report);
  if (report.isTlVerified) {
    return ownerClosed ? ReportStage.closedByOwner : ReportStage.pendingOwner;
  }
  if (!report.needsTlValidation) {
    return ownerClosed ? ReportStage.closedByOwner : ReportStage.pendingOwner;
  }
  return ReportStage.pendingTl;
}

/// Icon, color and label of a stage. The label of [ReportStage.closedByOwner]
/// depends on what the owner actually decided, hence [ownerStatus].
(IconData, Color, String) reportStageStyle(
  ReportStage stage, {
  String ownerStatus = '',
}) => switch (stage) {
  ReportStage.pendingTl => (
    Icons.hourglass_top,
    Colors.orange,
    'Pending TL Validation',
  ),
  ReportStage.rejectedByTl => (
    Icons.gpp_bad,
    Colors.red,
    'Rejected by TL — Needs Fix',
  ),
  ReportStage.validatedByTl => (Icons.verified, Colors.green, 'Approved by TL'),
  ReportStage.pendingOwner => (
    Icons.supervisor_account,
    Colors.blue,
    'Pending Owner Approval',
  ),
  ReportStage.closedByOwner => switch (ownerStatus) {
    'rejected' => (Icons.cancel, Colors.red, 'Rejected by Owner'),
    'ordered' => (Icons.local_shipping, Colors.orange, 'Material Ordered'),
    'acknowledged' => (Icons.visibility, Colors.blue, 'Acknowledged by Owner'),
    _ => (Icons.check_circle, Colors.green, 'Approved by Owner'),
  },
};

/// Human wording for a thread event, so a bubble says what happened instead of
/// only showing media (the previous timeline printed nothing).
String reportActionLabel(String action) => switch (action) {
  'submit' => 'Reported',
  'resubmit' => 'Fixed & resubmitted',
  'reject' => 'Rejected',
  'fix_note' => 'Fix explanation',
  'comment' => 'Message',
  _ => 'Update',
};

/// The actor a chat message is attributed to, derived from the compile-time
/// role (`--dart-define=USER_ROLE=...`). Only used to label messages and to
/// pick the wording of the composer — never to gate functionality.
String defaultActorForRole() => switch (const String.fromEnvironment(
  'USER_ROLE',
  defaultValue: 'subcontractor',
)) {
  'team_leader' => 'tl',
  'owner' => 'owner',
  _ => 'sub',
};

/// The shared Subcontractor <-> Team Leader thread for one report.
///
/// The thread *is* the report's `timelineEvents`: every bubble is one immutable
/// event (submission, rejection with its reason, fix explanation, message), so
/// the whole dispute history is preserved and travels with the report through
/// the existing sync — no second chat model, no second table.
///
/// Reused by the report sheet today, and by the History card in a later step.
class ReportChatThread extends StatelessWidget {
  const ReportChatThread({super.key, required this.report, this.emptyHint});

  final Report report;

  /// Shown when the report has no events at all yet.
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final events = report.parseTimelineEvents();
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          emptyHint ?? 'No messages yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      );
    }
    return Column(
      children: [
        for (final event in events) ...[
          _ChatBubble(event: event),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One immutable chat bubble: subcontractor events lean left, Team Leader
/// events lean right, and a rejection is ringed in red.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final actor = (event['actor'] ?? '').toString();
    final action = (event['action'] ?? '').toString();
    final text = (event['text'] ?? '').toString();
    final isSub = actor == 'sub';
    final isReject = action == 'reject';
    final when = DateTime.tryParse((event['time'] ?? '').toString())?.toLocal();
    final photo = ReportLocalService.resolveMedia(
      (event['photoUrl'] ?? '').toString(),
      '',
    );
    final voice = ReportLocalService.resolveMedia(
      (event['voiceUrl'] ?? '').toString(),
      '',
    );
    final hasPhoto = photo.origin != MediaOrigin.none;
    final hasVoice = voice.origin != MediaOrigin.none;
    final accent = isReject
        ? Colors.red
        : (isSub ? Colors.blue.shade800 : Colors.blueGrey);
    final background = isReject
        ? Colors.red.shade50
        : (isSub ? Colors.blue.shade50 : Colors.grey.shade100);

    return Align(
      alignment: isSub ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: isReject ? Border.all(color: Colors.red, width: 2) : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSub ? Icons.engineering_outlined : Icons.gavel,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSub ? 'Subcontractor' : 'Team Leader',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
                Text(
                  reportActionLabel(action),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                if (when != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMM, HH:mm').format(when),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text, style: const TextStyle(fontSize: 15, height: 1.35)),
            ],
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _eventPhoto(
                    photo.location,
                    photo.origin == MediaOrigin.network,
                  ),
                ),
              ),
            ],
            if (hasVoice) ...[
              const SizedBox(height: 8),
              TimelineAudioPlayer(
                voicePath: voice.location,
                voiceUrl: voice.location,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Thread media works offline and online: the local file is used while it
  /// still exists, the cached cloud copy otherwise.
  Widget _eventPhoto(String location, bool isNetwork) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: location,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
    return Image.file(
      File(location),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.broken_image),
      ),
    );
  }
}

/// The report-type emoji used on the sheet's type chip (🔨 work, ️ problem,
/// 📦 material).
String reportTypeEmoji(String type) => switch (type) {
  'problem' => '⚠️',
  'material' => '📦',
  _ => '🔨',
};

/// Sends one chat message for a report. Injected in tests; the default appends
/// the event locally (offline-first) and queues it for the cloud.
typedef ReportCommentSender =
    Future<void> Function(Report report, String text, String actor);

/// Live view of one report, so the sheet keeps up with writes made underneath
/// it (a sync pulling in the Team Leader's answer, a background edit). An
/// emission of null means "no local record" and the sheet keeps its snapshot.
typedef ReportWatcher = Stream<Report?> Function(int reportId);

/// Opens the report's location in the app's own map — never an external app.
typedef ReportLocationOpener =
    void Function(BuildContext context, Report report);

/// A role-specific giant action. Returning true closes the sheet (the action is
/// complete); false keeps it open so the user can carry on in the same context.
///
/// The [BuildContext] is the sheet's own context, so pushing a camera or
/// confirmation route from here stacks that route *above* the sheet instead of
/// being clipped inside it.
typedef ReportActionCallback =
    Future<bool> Function(BuildContext context, Report report);

/// One giant button at the bottom of the sheet.
class ReportSheetAction {
  const ReportSheetAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final ReportActionCallback onPressed;
}

/// The role-specific bottom bar of the sheet.
///
/// Empty [buttons] is a legitimate configuration: the sheet then shows the
/// report's status banner instead, which is exactly what a closed or read-only
/// report needs. This is how the Team Leader gate, the subcontractor's
/// "Fix & Resubmit" and any future workflow plug in without editing the sheet.
class ReportSheetActions {
  const ReportSheetActions({this.buttons = const [], this.note});

  final List<ReportSheetAction> buttons;

  /// Optional one-line caption above the buttons.
  final String? note;

  bool get isEmpty => buttons.isEmpty;
}

/// Opens the report detail + chat sheet.
///
/// This is THE entry point: a list tile, a map marker and any dashboard call it
/// with the report they already hold, so the report looks and behaves the same
/// everywhere.
///
/// Returns true when a chat message was sent (the caller can refresh), and null
/// when the sheet was dismissed without a message.
Future<bool?> showReportDetailSheet(
  BuildContext context, {
  required Report report,
  ReportWatcher? watch,
  ReportCommentSender? sendComment,
  ReportLocationOpener? onOpenLocation,
  ReportSheetActions actions = const ReportSheetActions(),
  String? selfActor,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReportDetailBottomSheet(
      report: report,
      watch: watch ?? defaultWatchReport,
      sendComment: sendComment ?? defaultSendComment,
      onOpenLocation: onOpenLocation ?? _defaultOpenLocation,
      actions: actions,
      selfActor: selfActor ?? defaultActorForRole(),
    ),
  );
}

/// Live Isar view of one report. `Report.id == 0` means the report was never
/// persisted — the Owner's thin client builds its reports in memory — in which
/// case there is simply nothing to watch. Sync errors are swallowed: the sheet
/// simply stays on the caller's snapshot.
Stream<Report?> defaultWatchReport(int reportId) {
  if (reportId == 0) return Stream<Report?>.value(null);
  try {
    return DatabaseService.watchReport(reportId).handleError((_) {});
  } catch (e, st) {
    debugPrint('ReportSheet: cannot watch report $reportId: $e\n$st');
    return Stream<Report?>.value(null);
  }
}

/// Appends the message to the report's thread and queues it for the cloud.
///
/// The local append always succeeds, so an offline device still shows the
/// message immediately; the push retries on the next sync trigger, and
/// [SyncService] sends `timeline_events` on both its insert and update branch.
Future<void> defaultSendComment(
  Report report,
  String text,
  String actor,
) async {
  await DatabaseService.appendReportEvent(
    report,
    actor: actor,
    // A Team Leader message is a plain comment; a subcontractor message is the
    // explanation attached to his fix.
    action: actor == 'sub' ? 'fix_note' : 'comment',
    text: text,
  );
  unawaited(SyncService.syncPendingReports());
}

/// Opens the app's own site map (internal `flutter_map` screen) instead of
/// launching an external Google Maps app. Focusing that map on this report's
/// pin arrives with the map step.
void _defaultOpenLocation(BuildContext context, Report report) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SiteMapScreen()));
}

/// The reusable report sheet: photo, timestamp, GPS coordinates, validation
/// status, the Subcontractor <-> Team Leader thread, a context-aware message
/// box, and whatever giant action buttons the opening role passes in.
///
/// It owns no business logic of its own — everything that touches storage or a
/// workflow is injected ([watch], [sendComment], [onOpenLocation], [actions]),
/// which is what makes it openable from a list tile, a map marker or any
/// dashboard without duplicating a single line of that logic.
class ReportDetailBottomSheet extends StatefulWidget {
  const ReportDetailBottomSheet({
    super.key,
    required this.report,
    required this.watch,
    required this.sendComment,
    this.onOpenLocation = _defaultOpenLocation,
    this.actions = const ReportSheetActions(),
    this.selfActor = 'sub',
  });

  /// The report as the caller knows it. The sheet refreshes from [watch] as
  /// soon as a live copy is available.
  final Report report;

  final ReportWatcher watch;
  final ReportCommentSender sendComment;
  final ReportLocationOpener onOpenLocation;
  final ReportSheetActions actions;

  /// The person using the sheet: 'sub', 'tl' or 'owner'. Only decides the
  /// wording of the message box, never what is allowed.
  final String selfActor;

  @override
  State<ReportDetailBottomSheet> createState() =>
      _ReportDetailBottomSheetState();
}

class _ReportDetailBottomSheetState extends State<ReportDetailBottomSheet> {
  /// Latest copy of the report: the caller's snapshot until a live update
  /// arrives from [ReportDetailBottomSheet.watch].
  late Report _report;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<Report?>? _liveSub;

  /// True while a message is being written.
  bool _sending = false;

  /// Index of the action button currently running (null when idle), so only
  /// that button shows a spinner and every button is disabled meanwhile.
  int? _runningAction;

  /// True once a message was sent, so the caller knows to refresh when the
  /// sheet closes.
  bool _sentMessage = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _liveSub = widget
        .watch(widget.report.id)
        .listen(
          (latest) {
            if (!mounted || latest == null) return;
            setState(() => _report = latest);
          },
          onError: (Object e, StackTrace st) {
            debugPrint('ReportSheet: live view failed: $e\n$st');
          },
        );
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  ReportStage get _stage => reportStageOf(_report);

  /// True when the Team Leader rejected the report: the subcontractor now owes
  /// an explanation, so his message box is highlighted and re-worded.
  bool get _needsFix => _stage == ReportStage.rejectedByTl;

  bool get _isSub => widget.selfActor == 'sub';

  /// Sends the typed message: it goes straight into the report's shared thread
  /// (offline-first — the local append always succeeds, the cloud push retries).
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.sendComment(_report, text, widget.selfActor);
      if (!mounted) return;
      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _sending = false;
        _sentMessage = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent')));
    } catch (e, st) {
      debugPrint('ReportSheet: sending the message failed: $e\n$st');
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send — check connection')),
      );
    }
  }

  /// Runs one injected action, showing a spinner on that button only, then
  /// closes the sheet when the action reports that it is finished.
  Future<void> _runAction(int index) async {
    if (_runningAction != null) return;
    final action = widget.actions.buttons[index];
    setState(() => _runningAction = index);
    try {
      final close = await action.onPressed(context, _report);
      if (!mounted) return;
      setState(() => _runningAction = null);
      if (close) Navigator.of(context).pop(_sentMessage);
    } catch (e, st) {
      debugPrint('ReportSheet: action "${action.label}" failed: $e\n$st');
      if (!mounted) return;
      setState(() => _runningAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action.label} failed — check connection')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // The sheet takes almost the whole screen: on a phone this is the report
      // read *and* the conversation about it, so it has to breathe.
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          // Photo and thread share the remaining space, so the layout adapts to
          // every screen instead of overflowing on short devices.
          Expanded(flex: 4, child: _photoHeader(context)),
          _facts(context),
          const Divider(height: 1),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: ReportChatThread(report: _report),
            ),
          ),
          _composer(context),
          _actionBar(context),
        ],
      ),
    );
  }

  /// The giant action buttons injected by the opening surface, with a spinner
  /// on the one that is running. An empty configuration renders nothing so a
  /// closed report shows only its status banner.
  Widget _actionBar(BuildContext context) {
    final note = widget.actions.note;
    final buttons = widget.actions.buttons;
    if ((note == null || note.isEmpty) && buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null && note.isNotEmpty) ...[
            Text(
              note,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < buttons.length; i++) ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                onPressed: _runningAction != null ? null : () => _runAction(i),
                style: FilledButton.styleFrom(
                  backgroundColor: buttons[i].color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _runningAction == i
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(buttons[i].icon),
                label: Text(
                  buttons[i].label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (i < buttons.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  /// The submitted photo with the validation status pinned on it, so the very
  /// first thing anyone sees is what was reported and where it stands.
  Widget _photoHeader(BuildContext context) {
    final (icon, color, label) = reportStageStyle(
      _stage,
      ownerStatus: _report.ownerStatus,
    );
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReportThumbnail(report: _report),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(_sentMessage),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.close, size: 28),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Type, timestamp and GPS coordinates — the three facts anyone needs before
  /// reading the thread. The coordinate row opens the app's own map.
  Widget _facts(BuildContext context) {
    final when = DateFormat(
      'EEE d MMM, HH:mm',
    ).format(_report.timestamp.toLocal());
    final hasGps = _report.lat != 0 || _report.lng != 0;
    final coords = hasGps
        ? '${_report.lat.toStringAsFixed(5)}, ${_report.lng.toStringAsFixed(5)}'
        : 'No GPS captured';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeChip(_report.type),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  when,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: hasGps
                ? () => widget.onOpenLocation(context, _report)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(coords, style: const TextStyle(fontSize: 14)),
                  ),
                  if (hasGps)
                    Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Emoji + word for the report type, color-coded like the map pins.
  Widget _typeChip(String type) {
    final (background, foreground) = switch (type) {
      'problem' => (Colors.red.shade50, Colors.red.shade800),
      'material' => (Colors.amber.shade100, Colors.orange.shade900),
      _ => (Colors.blue.shade50, Colors.blue.shade800),
    };
    final label = switch (type) {
      'problem' => 'Problem',
      'material' => 'Material',
      _ => 'Work',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${reportTypeEmoji(type)} $label',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }

  /// The message box. It is highlighted (red border, explanation wording) when
  /// the Team Leader rejected the report, so the subcontractor can say how he
  /// fixed it — the "chat input on rejected" behaviour, visible at a glance.
  Widget _composer(BuildContext context) {
    final highlight = _needsFix && _isSub;
    final hint = _needsFix
        ? (_isSub
              ? 'Explain how you fixed it…'
              : 'Write a message about the fix…')
        : (_isSub ? 'Explain or ask something…' : 'Write a message…');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.red.shade50 : Colors.white,
        border: Border(
          top: BorderSide(
            color: highlight ? Colors.red : Colors.grey.shade300,
            width: highlight ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            height: 56,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
