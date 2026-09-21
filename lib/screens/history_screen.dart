import 'package:flutter/material.dart';

import '../models/report.dart';
import '../role.dart';
import '../services/database_service.dart';
import '../widgets/report_sheet_actions.dart';
import '../widgets/traffic_card.dart';

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
                    final label = dayGroupLabel(
                      report.timestamp.toLocal(),
                    );
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
                      entries.add(
                        TrafficCard(
                          report: report,
                          isTeamLeader: _isTeamLeader,
                          onTap: () => _openReport(report),
                        ),
                      );
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
