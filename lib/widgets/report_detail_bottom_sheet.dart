import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../screens/site_map_screen.dart';
import '../services/database_service.dart';
import 'report_stage.dart';
import 'report_thumbnail.dart';
import 'report_timeline.dart';
import 'tl_validation_badge.dart';

// The report-stage vocabulary ([ReportStage], [reportStageOf],
// [reportStageStyle], [reportActionLabel], [reportTypeEmoji]) lives in
// `report_stage.dart` so the chat timeline can share it without importing this
// widget. It is re-exported here so every existing importer of this file keeps
// compiling untouched.
export 'report_stage.dart';

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
/// The actor a chat message is attributed to, derived from the compile-time
/// role (`--dart-define=USER_ROLE=...`). Only used to label the bubbles a
/// capture flow adds to the thread — never to gate functionality.
String defaultActorForRole() => switch (const String.fromEnvironment(
  'USER_ROLE',
  defaultValue: 'subcontractor',
)) {
  'team_leader' => 'tl',
  'owner' => 'owner',
  _ => 'sub',
};

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

/// One role-specific action in the sheet's bottom bar.
///
/// The bar is deliberately written out: one action fills the whole width,
/// three share it 33/34/33, and each one is a giant solid-coloured button
/// (icon + short caption) that runs its flow on a single tap — never an
/// ambiguous icon chip. The sheet itself stays workflow-free: the wording,
/// the colours and the flows all come from the injected action.
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

  /// The flow run when the button is tapped.
  final ReportActionCallback onPressed;
}

/// The role-specific bottom bar of the sheet.
///
/// Empty [buttons] is a legitimate configuration: the sheet then shows either
/// nothing (a report nobody is asked to act on right now) or the disabled grey
/// bar of a report that is already decided ('WORK CLOSED' once the owner has the
/// last word). This is how the Team Leader gate, the subcontractor's
/// "Fix & Resubmit" and any future workflow plug in without editing the sheet.
class ReportSheetActions {
  const ReportSheetActions({this.buttons = const [], this.note});

  final List<ReportSheetAction> buttons;

  /// Optional one-line caption above the buttons.
  final String? note;

  bool get isEmpty => buttons.isEmpty;
}

/// Opens the report detail sheet.
///
/// This is THE entry point: a list tile, a map marker and any dashboard call it
/// with the report they already hold, so the report looks and behaves the same
/// everywhere.
///
/// The thread is **read-only**: the only way a message joins the timeline is a
/// capture flow (Reject & Request Fix, Fix & Resubmit) reached from the bottom
/// bar, so this sheet has no text input of any kind.
///
/// Returns true when an action changed the report (the caller can refresh), and
/// null when the sheet was dismissed without a decision.
Future<bool?> showReportDetailSheet(
  BuildContext context, {
  required Report report,
  ReportWatcher? watch,
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

/// Opens the app's own site map (internal `flutter_map` screen) instead of
/// launching an external Google Maps app, centered on this report's pin.
void _defaultOpenLocation(BuildContext context, Report report) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SiteMapScreen(focusReport: report),
    ),
  );
}

/// The reusable report sheet: a WhatsApp-Profile header (circular photo,
/// type, timestamp, validation badge, map button),
/// the WhatsApp-style Subcontractor <-> Team Leader thread — strictly read-only,
/// with no text input anywhere — and the giant role-specific buttons the opening
/// role passes in.
///
/// It owns no business logic of its own — everything that touches storage or a
/// workflow is injected ([watch], [onOpenLocation], [actions]), which is what
/// makes it openable from a list tile, a map marker or any dashboard without
/// duplicating a single line of that logic.
class ReportDetailBottomSheet extends StatefulWidget {
  const ReportDetailBottomSheet({
    super.key,
    required this.report,
    required this.watch,
    this.onOpenLocation = _defaultOpenLocation,
    this.actions = const ReportSheetActions(),
    this.selfActor = 'sub',
  });

  /// The report as the caller knows it. The sheet refreshes from [watch] as
  /// soon as a live copy is available.
  final Report report;

  final ReportWatcher watch;
  final ReportLocationOpener onOpenLocation;
  final ReportSheetActions actions;

  /// The person using the sheet: 'sub', 'tl' or 'owner'. Only labels the bubbles
  /// the capture flows add, never what is allowed.
  final String selfActor;

  @override
  State<ReportDetailBottomSheet> createState() =>
      _ReportDetailBottomSheetState();
}

class _ReportDetailBottomSheetState extends State<ReportDetailBottomSheet> {
  /// Latest copy of the report: the caller's snapshot until a live update
  /// arrives from [ReportDetailBottomSheet.watch].
  late Report _report;

  StreamSubscription<Report?>? _liveSub;

  /// Index of the action button currently running (null when idle), so only
  /// that button shows a spinner and every button is disabled meanwhile.
  int? _runningAction;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    // The thread is on screen: the report's History card drops its unread dot.
    unawaited(DatabaseService.markReportRead(_report));
    _liveSub = widget
        .watch(widget.report.id)
        .listen(
          (latest) {
            if (!mounted || latest == null) return;
            setState(() => _report = latest);
            // A live refresh the user is looking at counts as reading too:
            // re-mark read so a dot never lingers on an open thread.
            unawaited(DatabaseService.markReportRead(latest));
          },
          onError: (Object e, StackTrace st) {
            debugPrint('ReportSheet: live view failed: $e\n$st');
          },
        );
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  ReportStage get _stage => reportStageOf(_report);

  /// Runs one injected action, showing a spinner on that button only, then
  /// closes the sheet when the action reports that it is finished.
  Future<void> _runAction(int index) async {
    if (_runningAction != null) return;
    await _runFlow(index, widget.actions.buttons[index]);
  }

  /// Runs one flow, then pops the sheet with true when it changed the report
  /// (the caller refreshes) or keeps it open when the flow returned false.
  Future<void> _runFlow(int index, ReportSheetAction action) async {
    setState(() => _runningAction = index);
    try {
      final close = await action.onPressed(context, _report);
      if (!mounted) return;
      setState(() => _runningAction = null);
      // The user's own capture flow just appended an event (which flagged the
      // card unread): the actor obviously saw it, so re-mark read — even when
      // the sheet pops, the History card must not show a self-made dot.
      unawaited(DatabaseService.markReportRead(_report));
      if (close) Navigator.of(context).pop(true);
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
          // ── Top 8%: compact header (thumbnail + type + time) ────────────────
          _compactHeader(context),

          // ── Middle 82%: the role-styled timeline ─────────────────────────────
          // The Owner reads it as a Git commit log; the field roles keep the
          // WhatsApp-style chat.
          Expanded(
            child: widget.selfActor == 'owner'
                ? GitReportTimeline(
                    report: _report,
                    emptyHint: 'No events yet.',
                  )
                : ReportTimeline(
                    report: _report,
                    emptyHint: 'No messages yet.',
                  ),
          ),

          // ── Bottom ~10%: the giant role-specific action bar ──────────────────
          _actionBar(context),
        ],
      ),
    );
  }

  /// The WhatsApp-Profile header: a circular photo avatar, the big report
  /// type with the bold timestamp under it, the validation badge, and a map
  /// button that opens the internal site map centered on the report's pin.
  /// Content-sized (no fixed height), so it can never pixel-overflow, and it
  /// never shows raw latitude/longitude text.
  Widget _compactHeader(BuildContext context) {
    final (icon, color, label) = reportStageStyle(
      _stage,
      ownerStatus: _report.ownerStatus,
    );
    final when = DateFormat(
      'd MMM, hh:mm a',
    ).format(_report.timestamp.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Circular photo of the report (Hybrid Shield: local file while it
          // exists, cached cloud copy otherwise, placeholder icon if none).
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            child: ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: ReportThumbnail(
                  report: _report,
                  size: 56,
                  iconSize: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Report type, then the full timestamp with the TL validation chip
          // beside it, then the stage badge.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _typeTitle(_report.type),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _typeColor(_report.type),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Date/Time with the TL badge beside it so the verdict is the
                // first thing seen on opening the report. Expanded + ellipsis
                // keep the row from ever pixel-overflowing.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        when,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(flex: 0, child: TlValidationBadge(report: _report)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // The map button opens the internal site map centered on the
          // report's pin — no raw coordinates in the header, ever.
          IconButton(
            icon: const Icon(Icons.map_outlined),
            color: Colors.blue,
            tooltip: 'Open map',
            onPressed: () => widget.onOpenLocation(context, _report),
          ),
          // Close button.
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  /// Emoji + uppercase word for the report type, colored like the map pins.
  String _typeTitle(String type) => switch (type) {
    'problem' => '${reportTypeEmoji(type)} PROBLEM',
    'material' => '${reportTypeEmoji(type)} MATERIAL',
    _ => '${reportTypeEmoji(type)} WORK',
  };

  Color _typeColor(String type) => switch (type) {
    'problem' => Colors.red.shade800,
    'material' => Colors.orange.shade900,
    _ => Colors.blue.shade800,
  };

  /// The report's bottom action bar: the giant, unambiguous decision.
  ///
  /// The injected actions are rendered as solid full-width buttons. One action
  /// fills the whole bar; the Team Leader's three-way gate shares it roughly
  /// 33/34/33. Every button runs its flow on a single tap.
  ///
  /// A report nobody can act on any more gets a disabled grey bar instead:
  /// 'WORK CLOSED' once the Owner had the last word, or the stage label with a
  /// lock (the Team Leader already signed the report off).
  Widget _actionBar(BuildContext context) {
    final note = widget.actions.note;
    final buttons = widget.actions.buttons;
    if (buttons.isEmpty) {
      if (isReportClosedByOwner(_report)) return _disabledBar('WORK CLOSED');
      if (!reportStaysActionableLock(_report)) return const SizedBox.shrink();
      final label = reportStageStyle(
        _stage,
        ownerStatus: _report.ownerStatus,
      ).$3;
      return _disabledBar(label, locked: true);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.grey.shade50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null && note.isNotEmpty) ...[
            Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                Expanded(child: _giantActionButton(context, i)),
                if (i < buttons.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The disabled grey bar: 'WORK CLOSED' for an owner-decided report, or the
  /// current stage plus a lock when the report is simply out of reach.
  Widget _disabledBar(String label, {bool locked = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      color: Colors.grey.shade200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            const Icon(Icons.lock, size: 26, color: Colors.grey),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// One giant action: an icon of size 28 with its caption underneath, on the
  /// action's own solid colour. A single action fills the bar; two or three
  /// share it equally via [Expanded], so they can never pixel-overflow.
  Widget _giantActionButton(BuildContext context, int index) {
    final action = widget.actions.buttons[index];
    final running = _runningAction == index;
    return Material(
      color: action.color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: running || _runningAction != null
            ? null
            : () => _runAction(index),
        child: SizedBox(
          width: double.infinity,
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (running)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              else
                Icon(action.icon, size: 28, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
