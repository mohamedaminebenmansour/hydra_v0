import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../services/event_media.dart';
import '../services/report_local_service.dart';
import 'report_stage.dart';

// ---------------------------------------------------------------------------
// WhatsApp-style chat timeline for a single report.
//
// The original report photo is the FIRST bubble (it already lives in the
// report's first `timelineEvents` entry - the 'submit' event - so no separate
// header photo is rendered). Subcontractor events lean LEFT on a light grey
// background, Team Leader events lean RIGHT on a light blue one, and a
// rejection is ringed in red.
//
// The list is reversed (`reverse: true` over the reversed event list), so the
// newest event is always pinned to the bottom of the thread like a real chat,
// without animating the scroll position on every rebuild.
// ---------------------------------------------------------------------------

/// The shared Subcontractor <-> Team Leader thread for one report, rendered as
/// a WhatsApp-style chat list.
///
/// The timeline *is* the report's `timelineEvents`: every bubble is one
/// immutable event (submission, rejection, fix explanation, message), and the
/// very first event carries the original report photo, so it shows up as the
/// first chat bubble instead of a static header photo.
class ReportTimeline extends StatelessWidget {
  const ReportTimeline({super.key, required this.report, this.emptyHint});

  final Report report;

  /// Shown when the report has no events at all yet.
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final events = _threadEvents(report);
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            emptyHint ?? 'No messages yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return ListView.separated(
      // Reversed: index 0 is the newest event, drawn at the bottom edge.
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _ChatBubble(event: events[events.length - 1 - index]),
    );
  }
}

// ---------------------------------------------------------------------------
// The Owner's Git-style commit log.
//
// Same event source as the chat, rendered like a `git log --graph`: one row
// per event, a colored node (sub = grey, tl = blue, owner = green) on a
// vertical line, actor + action + time beside it, and a small thumbnail of
// the event's photo underneath. Chronological (oldest first), like a commit
// history ? the opposite of the chat's newest-at-the-bottom.
// ---------------------------------------------------------------------------

/// Node color per actor: Sub (Grey), TL (Blue), Owner (Green).
Color gitActorColor(String actor) => switch (actor) {
  'tl' => Colors.blue,
  'owner' => Colors.green,
  _ => Colors.grey,
};

/// Display name per actor.
String gitActorName(String actor) => switch (actor) {
  'tl' => 'Team Leader',
  'owner' => 'Owner',
  _ => 'Subcontractor',
};

/// The Git-style timeline: one connected row per event, oldest first.
class GitReportTimeline extends StatelessWidget {
  const GitReportTimeline({super.key, required this.report, this.emptyHint});

  final Report report;

  /// Shown when the report has no events at all yet.
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final events = _threadEvents(report);
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            emptyHint ?? 'No events yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: events.length,
      itemBuilder: (context, index) => _GitCommitRow(
        event: events[index],
        isFirst: index == 0,
        isLast: index == events.length - 1,
      ),
    );
  }
}

/// One commit row: the node column (circle + vertical connector), then the
/// text block (actor, action, time) and the event's photo thumbnail.
class _GitCommitRow extends StatelessWidget {
  const _GitCommitRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final Map<String, dynamic> event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final actor = (event['actor'] ?? '').toString();
    final action = (event['action'] ?? '').toString();
    final text = (event['text'] ?? '').toString();
    final when = DateTime.tryParse((event['time'] ?? '').toString())?.toLocal();

    // The bubble media is a (path, url) pair: the local file while it exists,
    // the cloud copy once it has been reclaimed — and for events written by
    // older builds, the single legacy field, which both accessors understand.
    final eventPhoto = eventPhotoOf(event);
    final media = ReportLocalService.resolveMedia(
      eventPhoto.path,
      eventPhoto.url,
    );
    final hasPhoto = media.origin != MediaOrigin.none;
    final nodeColor = gitActorColor(actor);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The commit-graph column: line above + node + line below.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The commit message: actor, action, time, then the photo.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gitActorName(actor),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: nodeColor.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    reportActionLabel(action),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  if (when != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM, HH:mm').format(when),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  if (hasPhoto) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _buildThumbnail(
                          media.location,
                          media.origin == MediaOrigin.network,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small event photo: local file or cached network image.
  Widget _buildThumbnail(String location, bool isNetwork) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: location,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported, size: 20),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, size: 20),
        ),
      );
    }
    return Image.file(
      File(location),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, size: 20),
      ),
    );
  }
}

/// The report's events in chronological order, with the original report photo
/// guaranteed to appear as the very first bubble.
///
/// Reports captured before the chat existed (or by an older build) may have no
/// 'submit' event at all, and a 'submit' event may carry no photo; both cases
/// are repaired here so the first thing anyone reads is what was reported.
List<Map<String, dynamic>> _threadEvents(Report report) {
  // The report's own media is the (path, url) pair, so the opening bubble can
  // still be shown after the local file is reclaimed.
  final hasReportMedia =
      report.photoPath.isNotEmpty ||
      hostedUrl(report.photoUrl) != null ||
      report.voicePath.isNotEmpty ||
      hostedUrl(report.voiceUrl) != null;
  final events = report.parseTimelineEvents();
  if (events.isEmpty) {
    if (!hasReportMedia) return const [];
    return [_submitEvent(report)];
  }
  final firstPhoto = eventPhotoOf(events.first);
  final firstHasPhoto =
      ReportLocalService.resolveMedia(
        firstPhoto.path,
        firstPhoto.url,
      ).origin !=
      MediaOrigin.none;
  if (firstHasPhoto || !hasReportMedia) return events;
  return [_submitEvent(report), ...events];
}

/// The synthetic 'submit' bubble used when the stored thread is missing its
/// opening event: the report's own photo (and voice note) at creation time,
/// local file and cloud copy alike.
Map<String, dynamic> _submitEvent(Report report) => {
  'actor': 'sub',
  'action': 'submit',
  'text': '',
  'photoPath': report.photoPath,
  'photoUrl': report.photoUrl,
  'voicePath': report.voicePath,
  'voiceUrl': report.voiceUrl,
  'time': report.timestamp.toUtc().toIso8601String(),
};

/// One immutable chat bubble: WhatsApp-style.
///
/// Subcontractor events lean left on light grey, Team Leader events lean right
/// on light blue, and a rejection is a red bubble (right-aligned, like every TL
/// bubble). The photo (200x200, radius 12) and the slim pink/orange voice bar
/// both live inside the bubble, so several bubbles fit on one screen without
/// endless scrolling.
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

    // WhatsApp-style alignment: subcontractor = left, team leader = right.
    final crossAxisAlignment = isSub
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;

    // Background per role, with the rejection standing out as a red bubble.
    final background = isReject
        ? Colors.red.shade100
        : (isSub ? Colors.grey.shade200 : Colors.blue.shade50);
    final borderColor = isReject ? Colors.red : null;
    final actorColor = isReject
        ? Colors.red
        : (isSub ? Colors.blueGrey.shade800 : Colors.blue.shade800);

    final eventPhoto = eventPhotoOf(event);
    final eventVoice = eventVoiceOf(event);
    final media = ReportLocalService.resolveMedia(
      eventPhoto.path,
      eventPhoto.url,
    );
    final voice = ReportLocalService.resolveMedia(
      eventVoice.path,
      eventVoice.url,
    );
    final hasPhoto = media.origin != MediaOrigin.none;
    final hasVoice = voice.origin != MediaOrigin.none;

    return Align(
      alignment: isSub ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            // Header: actor icon + name + action chip.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSub ? Icons.engineering_outlined : Icons.gavel,
                  size: 16,
                  color: actorColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isSub ? 'Subcontractor' : 'Team Leader',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: actorColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ..._actionChip(action, actorColor),
              ],
            ),
            // Content: text / photo / voice bar.
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
            ],
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPhoto(
                  media.location,
                  media.origin == MediaOrigin.network,
                ),
              ),
            ],
            if (hasVoice) ...[
              const SizedBox(height: 8),
              _SlimVoiceBar(
                voicePath: voice.location,
                voiceUrl: voice.location,
                isNetwork: voice.origin == MediaOrigin.network,
              ),
            ],
            // Footer: time.
            if (when != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(when),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact WhatsApp-style action chip next to the actor name (e.g.
  /// 'Reported', 'Message', 'Rejected'), so a bubble says what happened instead
  /// of only showing media.
  List<Widget> _actionChip(String action, Color color) {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          reportActionLabel(action),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    ];
  }

  /// Thread media works offline and online: the local file is used while it
  /// still exists, the cached cloud copy otherwise. Sized to 200x200 so several
  /// photos fit on one screen without endless scrolling.
  Widget _buildPhoto(String location, bool isNetwork) {
    const pw = 200.0;
    const ph = 200.0;
    if (isNetwork) {
      return SizedBox(
        width: pw,
        height: ph,
        child: CachedNetworkImage(
          imageUrl: location,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported, size: 32),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, size: 32),
          ),
        ),
      );
    }
    return SizedBox(
      width: pw,
      height: ph,
      child: Image.file(
        File(location),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, size: 32),
        ),
      ),
    );
  }
}

/// A slim WhatsApp-style voice note bar: a compact pink/orange pill with a
/// play/pause button, a progress fill and the duration. ~160x32, so it sits
/// inside a chat bubble without dominating the screen.
class _SlimVoiceBar extends StatefulWidget {
  const _SlimVoiceBar({
    required this.voicePath,
    required this.voiceUrl,
    required this.isNetwork,
  });

  final String voicePath;
  final String voiceUrl;
  final bool isNetwork;

  @override
  State<_SlimVoiceBar> createState() => _SlimVoiceBarState();
}

class _SlimVoiceBarState extends State<_SlimVoiceBar> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    // audioplayers 6 streams playback state instead of polling for it.
    _posSub = _player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _position = d);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == PlayerState.playing;
        if (state == PlayerState.completed) _position = _duration;
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      // Replaying a finished note restarts it from the beginning.
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seek(Duration.zero);
        _position = Duration.zero;
      }
      await _player.play(
        widget.isNetwork
            ? UrlSource(widget.voiceUrl)
            : DeviceFileSource(widget.voicePath),
      );
    } catch (e, st) {
      debugPrint('_SlimVoiceBar: play failed: $e\n$st');
    }
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fill = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final track = Colors.orange.shade100;
    final fillColor = Colors.orange.shade400; // pink/orange
    return SizedBox(
      width: 160,
      height: 32,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fillColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  size: 16,
                  color: fillColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(_duration),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fillColor,
            ),
          ),
        ],
      ),
    );
  }
}
