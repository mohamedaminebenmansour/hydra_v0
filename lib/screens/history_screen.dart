import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/report_thumbnail.dart';
import 'report_detail_screen.dart';

/// Displays all locally saved Reports in a scrollable list with a colored
/// status border (Yellow = pending, Green = synced).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  /// Segmentation: which list the user is viewing.
  String _view = 'ACTIVE';

  /// Active type filter from the chip row ('All', 'Work', 'Problem', 'Material').
  String _filter = 'All';

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
    // Opening from the 'TO VERIFY' tab enables the Team Leader gate buttons.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(
          report: report,
          validationMode: _view == 'TO VERIFY',
        ),
      ),
    );
  }

  /// True when [report] belongs to the currently selected view.
  bool _matchesView(Report report) {
    if (_view == 'TO VERIFY') {
      return report.needsTlValidation;
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

  /// A compact sync-status badge shown on each history card.
  Widget _syncBadge(Report report) {
    return switch (report.syncState) {
      SyncState.synced => _badge(
          Icons.check_circle,
          Colors.green,
          'Synced',
          null,
        ),
      SyncState.uploading => _badge(
          Icons.hourglass_top,
          Colors.amber.shade700,
          'Syncing…',
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      SyncState.failed => _badge(
          Icons.error,
          Colors.red,
          'Tap to retry',
          null,
          () => _retryReport(report),
        ),
      SyncState.local => _badge(
          Icons.cloud_off,
          Colors.grey,
          'Saved on phone',
          null,
        ),
    };
  }

  Widget _badge(
    IconData icon,
    Color color,
    String label, [
    Widget? trailing,
    VoidCallback? onTap,
  ]) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }

  Future<void> _retryReport(Report report) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Retrying sync…')),
    );
    await SyncService.retryReport(report.id);
  }

  /// Status avatar (CircleAvatar + caption) remembered from the owner's
  /// decision. Dominant icon, serving also as a first-time onboarding cue.
  Widget _statusAvatar(Report report) => _statusAvatarFor(report.ownerStatus);

  String _statusWord(Report report) => _statusWordFor(report.ownerStatus);

  Widget _statusAvatarFor(String s) {
    final (bg, fg, icon) = switch (s) {
      'validated' || 'approved' => (Colors.green, Colors.white, Icons.check),
      'acknowledged' => (Colors.blue, Colors.white, Icons.visibility),
      'ordered' => (Colors.orange, Colors.white, Icons.local_shipping),
      'rejected' => (Colors.red, Colors.white, Icons.close),
      _ => (Colors.yellow, Colors.black, Icons.hourglass_top),
    };
    return CircleAvatar(radius: 22, backgroundColor: bg, child: Icon(icon, size: 24, color: fg));
  }

  String _statusWordFor(String s) => switch (s) {
        'validated' => 'Validated',
        'approved' => 'Approved',
        'acknowledged' => 'Acknowledged',
        'ordered' => 'Ordered',
        'rejected' => 'Rejected',
        _ => 'Waiting',
      };

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

  /// Border color based on ownerStatus: Yellow=pending, Green=validated/acknowledged,
  /// Orange=ordered, Red=rejected.
  Color _borderColorForStatus(String ownerStatus) => switch (ownerStatus) {
        'validated' || 'acknowledged' => Colors.green,
        'ordered' => Colors.orange,
        'rejected' => Colors.red,
        _ => Colors.yellow,
      };

  /// One glanceable, icon-dominant report tile: a 100x100 photo on the left
  /// with a colored status border, a giant type icon and the
  /// timestamp on the right, and a clean status row underneath.
  Widget _trafficCard(Report report) {
    final borderColor = _borderColorForStatus(report.ownerStatus);
    final thumb = ReportThumbnail(report: report, size: 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openReport(report),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 100x100 photo with a colored status border - no overlays.
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
              // Info section: type icon + date/time on top, status row on bottom.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: giant type icon + full date and time.
                    Row(
                      children: [
                        Icon(_typeIcon(report), size: 30, color: _typeColor(report)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMM, HH:mm').format(report.timestamp.toLocal()),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Bottom row: colored dot + status text.
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: borderColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusWord(report),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                    segments: const [
                      ButtonSegment(
                        value: 'ACTIVE',
                        label: Text('ACTIVE'),
                        icon: Icon(Icons.fiber_new),
                      ),
                      ButtonSegment(
                        value: 'HISTORY',
                        label: Text('HISTORY'),
                        icon: Icon(Icons.history),
                      ),
                      ButtonSegment(
                        value: 'TO VERIFY',
                        label: Text('TO VERIFY'),
                        icon: Icon(Icons.fact_check),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _view = selection.first;
                        // Problem reports never pass through the gate, so a
                        // leftover 'Problem' type filter would always leave the
                        // TO VERIFY list empty. Reset it on entry.
                        if (_view == 'TO VERIFY') _filter = 'All';
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
                stream: DatabaseService.watchAllReports(),
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
                        padding:
                            const EdgeInsets.only(top: 12, left: 4, right: 4),
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
