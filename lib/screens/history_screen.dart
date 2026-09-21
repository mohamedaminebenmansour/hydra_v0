import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../role.dart';
import '../services/database_service.dart';
import '../widgets/report_thumbnail.dart';
import '../widgets/report_sheet_actions.dart';
import '../widgets/tl_validation_badge.dart';

/// Short, locale-friendly label for an optional timestamp, e.g. '9 Sep, 10:00'.
/// Returns '' for null so tracker nodes can omit the time column.
String historyTimeLabel(DateTime? time) {
  if (time == null) return '';
  return DateFormat('d MMM, HH:mm').format(time.toLocal());
}

/// TL gate verdict as a (color, icon, label, timestamp) tuple for the tracker.
/// The badge vocabulary (colour + icon + wording) is defined once in
/// [tlValidationBadgeStyle] so the History card and the report detail header
/// always agree.
(Color, IconData, String, DateTime?) historyTlNode(Report report) {
  final (color, icon, label) = tlValidationBadgeStyle(report);
  return (color, icon, label, report.tlValidatedAt);
}

/// Whether the TL verdict surfaces a dispute bubble on the tracker node.
bool historyTlHasDispute(Report report) =>
    report.tlValidationType == 'rejected';

/// Owner decision as a (color, label, timestamp) tuple for the tracker.
(Color, String, DateTime?) historyOwnerNode(Report report) {
  final ts = report.ownerStatusAt;
  return switch (report.ownerStatus) {
    'validated' || 'approved' => (Colors.green, 'Validated', ts),
    'acknowledged' => (Colors.blue, 'Acknowledged', ts),
    'ordered' => (Colors.orange, 'Ordered', ts),
    'rejected' => (Colors.red, 'Rejected', ts),
    _ => (Colors.yellow, 'Waiting', null),
  };
}

/// Displays all locally saved Reports in a scrollable list with a colored
/// status border (Yellow = pending, Green = synced).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.userRoleOverride, this.reportsStream});

  /// Test seam for the compile-time role. Null falls back to the [userRole]
  /// dart-define; tests pass a role explicitly to exercise both in one run.
  final String? userRoleOverride;

  /// Injectable report stream (defaults to Isar's live query). Isar streams
  /// don't run in the widget-test VM, so tests pass an in-memory stream.
  final Stream<List<Report>>? reportsStream;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  /// Segmentation: which list the user is viewing.
  String _view = 'ACTIVE';

  /// Active type filter from the chip row ('All', 'Work', 'Problem', 'Material').
  String _filter = 'All';

  /// True when the signed-in user is a Team Leader (see [userRoleOverride]).
  bool get _isTeamLeader =>
      (widget.userRoleOverride ?? userRole) == 'team_leader';

  /// The segments of the view selector. A subcontractor gets REWORK — the
  /// rejected reports he owes a fix on — instead of the Team Leader's
  /// TO VERIFY gate queue.
  List<ButtonSegment<String>> get _viewSegments => [
    const ButtonSegment(
      value: 'ACTIVE',
      label: Text('ACTIVE'),
      icon: Icon(Icons.fiber_new),
    ),
    const ButtonSegment(
      value: 'HISTORY',
      label: Text('HISTORY'),
      icon: Icon(Icons.history),
    ),
    if (_isTeamLeader)
      const ButtonSegment(
        value: 'TO VERIFY',
        label: Text('TO VERIFY'),
        icon: Icon(Icons.fact_check),
      )
    else
      const ButtonSegment(
        value: 'REWORK',
        label: Text('🔧 REWORK'),
        icon: Icon(Icons.build_circle),
      ),
  ];
  @override
  void initState() {
    super.initState();
    // Kept for parity with other screens; the StreamBuilder below already
    // pushes fresh sorted data on every Isar write, so no manual reload is
    // needed.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openReport(Report report) async {
    // No reload needed after pop: the stream re-emits on any Isar change.
    // The sheet resolves its role-based bar (APPROVE / REJECT for a Team Leader,
    // FIX & RESUBMIT for a subcontractor) from the report and the signed-in role.
    await showDefaultReportDetailSheet(context, report);
  }

  /// True when [report] belongs to the currently selected view.
  bool _matchesView(Report report) {
    if (_view == 'TO VERIFY') {
      return report.needsTlValidation;
    }
    if (_view == 'REWORK') {
      // The subcontractor's to-do list: everything the TL rejected.
      return report.tlValidationType == 'rejected';
    }
    if (_view == 'HISTORY') {
      return report.ownerStatus == 'validated' ||
          report.ownerStatus == 'acknowledged' ||
          report.ownerStatus == 'rejected';
    }
    // ACTIVE: waiting on the owner, ordered, or still syncing locally.
    return report.ownerStatus == 'pending' ||
        report.ownerStatus == 'ordered' ||
        report.syncState != SyncState.synced;
  }

  /// True when [report] matches the selected type chip.
  bool _matchesType(Report report) {
    if (_filter == 'All') return true;
    return report.type == _filter.toLowerCase();
  }

  /// Day-group header ('TODAY', 'YESTERDAY', or a long date) for a local ts.
  String _dayLabel(DateTime local) {
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final now = DateTime.now();
    if (isSameDay(local, now)) return 'TODAY';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(local, yesterday)) return 'YESTERDAY';
    return DateFormat('EEEE, d MMMM').format(local);
  }

  IconData _typeIcon(Report r) => switch (r.type) {
    'work' => Icons.build,
    'problem' => Icons.warning,
    _ => Icons.inventory,
  };

  Color _typeColor(Report r) => switch (r.type) {
    'work' => Colors.grey,
    'problem' => Colors.red,
    _ => Colors.amber,
  };

  /// Border color based on ownerStatus: Yellow=pending, Green=validated/
  /// acknowledged, Orange=ordered, Red=rejected.
  Color _borderColorForStatus(String ownerStatus) => switch (ownerStatus) {
    'validated' || 'acknowledged' => Colors.green,
    'ordered' => Colors.orange,
    'rejected' => Colors.red,
    _ => Colors.yellow,
  };

  /// Icon matching each owner status for the tracker's leading glyph —
  /// a replacement for the old anonymous colored dot.
  IconData _ownerNodeIcon(String ownerStatus) => switch (ownerStatus) {
    'validated' || 'acknowledged' => Icons.verified,
    'ordered' => Icons.shopping_cart,
    'rejected' => Icons.close,
    _ => Icons.hourglass_top,
  };

  /// One tracker node: a fixed 18x18 leading icon/dot + small label + optional
  /// timestamp + optional dispute bubble.
  Widget _timelineNode({
    required Widget leading,
    required String label,
    DateTime? time,
    bool showDisputeBubble = false,
  }) {
    final timeText = historyTimeLabel(time);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: leading)),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timeText.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  timeText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (showDisputeBubble) ...[
          const SizedBox(width: 4),
          Icon(Icons.chat_bubble_outline, size: 13, color: Colors.red),
        ],
      ],
    );
  }

  /// Thin connector between tracker nodes so the 3 steps read as a timeline.
  Widget _timelineConnector() => Container(
    width: 2,
    height: 6,
    margin: const EdgeInsets.only(left: 8),
    color: Colors.grey.shade300,
  );

  /// The vertical Submitted -> TL -> Owner tracker. The TL step is HIDDEN for
  /// the Team Leader (they are the TL), who only tracks the Owner handoff.
  Widget _validationTracker(Report report) {
    final tl = historyTlNode(report);
    final nodes = <Widget>[
      _timelineNode(
        leading: Icon(Icons.check_circle, size: 16, color: Colors.grey),
        label: 'Submitted',
        time: report.timestamp,
      ),
      // Node 2: Team Leader gate - the verdict is a Visual Badge (icon +
      // colour) so Physical vs Remote is readable without reading text.
      if (!_isTeamLeader)
        _timelineNode(
          leading: Icon(tl.$2, size: 16, color: tl.$1),
          label: tl.$3,
          time: tl.$4,
          showDisputeBubble: historyTlHasDispute(report),
        ),
      // Node 3: Owner decision - visible to all roles. The tiny colored dot
      // is replaced by a matching Material icon in the owner-status colour,
      // consistent with the TL badge above it.
      Builder(
        builder: (_) {
          final owner = historyOwnerNode(report);
          return _timelineNode(
            leading: Icon(_ownerNodeIcon(report.ownerStatus), size: 16, color: owner.$1),
            label: owner.$2,
            time: owner.$3,
          );
        },
      ),
    ];
    final out = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      if (i > 0) out.add(_timelineConnector());
      out.add(nodes[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: out,
    );
  }

  /// One glanceable, icon-dominant report tile: a 100x100 photo on the left
  /// with the ownerStatus border, a giant type icon and timestamp on the right,
  /// and a 3-node validation tracker (Submitted -> TL -> Owner) underneath.
  Widget _trafficCard(Report report) {
    final borderColor = _borderColorForStatus(report.ownerStatus);
    final thumb = ReportThumbnail(report: report, size: 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openReport(report),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 100x100 photo with the thick owner-status border - no overlays.
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 3.0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: thumb,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right side: dominant type icon + the 3-node validation tracker.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _typeIcon(report),
                          size: 28,
                          color: _typeColor(report),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _validationTracker(report)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The unread dot (WhatsApp-style): something new happened on the
            // thread — a TL rejection, a resubmission, an owner decision —
            // and the user has not opened the sheet since.
            if (!report.isReadByUser)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  key: const Key('history_unread_dot'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented control: ACTIVE vs HISTORY vs TO VERIFY (the Team
            // Leader "Chef de Chantier Gate" queue). Scrollable so the three
            // segments can never overflow a narrow phone screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: SegmentedButton<String>(
                    segments: _viewSegments,
                    selected: {_view},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _view = selection.first;
                        // Problem reports never pass through the gate, so a
                        // leftover 'Problem' type filter would always leave the
                        // TO VERIFY list empty. Reset it on entry (same for
                        // REWORK, which lists every type).
                        if (_view == 'TO VERIFY' || _view == 'REWORK') {
                          _filter = 'All';
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            // Type filter chips.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final label in const [
                    'All',
                    'Work',
                    'Problem',
                    'Material',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == label,
                        onSelected: (_) => setState(() => _filter = label),
                      ),
                    ),
                ],
              ),
            ),
            // Filtered report list.
            Expanded(
              child: StreamBuilder<List<Report>>(
                stream:
                    widget.reportsStream ?? DatabaseService.watchAllReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reports = snapshot.data ?? const <Report>[];
                  // Filter BEFORE rendering: view, then type.
                  final filtered = reports
                      .where((r) => _matchesView(r) && _matchesType(r))
                      .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          switch (_view) {
                            'ACTIVE' => 'No active items. All caught up!',
                            'TO VERIFY' => 'Nothing to verify.',
                            'REWORK' => 'Nothing to rework. All clear!',
                            _ => 'No history yet.',
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }

                  // Group the (already newest-first) list by day.
                  final headers = <String>[];
                  final byDay = <String, List<Report>>{};
                  for (final report in filtered) {
                    final label = _dayLabel(report.timestamp.toLocal());
                    if (!byDay.containsKey(label)) {
                      byDay[label] = <Report>[];
                      headers.add(label);
                    }
                    byDay[label]!.add(report);
                  }

                  // Flatten into header + tile entries for a single ListView.
                  final entries = <Widget>[];
                  for (final label in headers) {
                    entries.add(
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 12,
                          left: 4,
                          right: 4,
                        ),
                        child: Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    );
                    for (final report in byDay[label]!) {
                      entries.add(_trafficCard(report));
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) => entries[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
