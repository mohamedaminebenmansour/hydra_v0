import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/report_thumbnail.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import '../widgets/report_sheet_actions.dart';

// ---------------------------------------------------------------------------
// The Team Leader's "Action Center" (Chef de Chantier Inbox).
//
// The inbox rules are pure functions: the queue is resolved by [tlInboxQueue]
// and rendered by [tlInboxTypeLabel] / [tlInboxTimeLabel], so the ordering can
// be unit-tested without pumping a widget.
// ---------------------------------------------------------------------------

/// Sort rank of a report type in the TL inbox: 'material' and 'problem' are
/// the ones a site cannot proceed without, so they float above plain 'work'.
int tlInboxRank(String type) => type == 'work' ? 1 : 0;

/// The inbox queue for [reports]: only what still waits for the Team Leader
/// ([Report.needsTlValidation] — 'work'/'material' without a gate decision;
/// 'problem' reports never pass the gate), sorted by [tlInboxRank] and then
/// OLDEST FIRST, so nothing on site gets forgotten.
List<Report> tlInboxQueue(List<Report> reports) {
  final queue = reports.where((r) => r.needsTlValidation).toList();
  queue.sort((a, b) {
    final rank = tlInboxRank(a.type).compareTo(tlInboxRank(b.type));
    if (rank != 0) return rank;
    return a.timestamp.compareTo(b.timestamp);
  });
  return queue;
}

/// The big word on an inbox row ('🔨 WORK REQUEST', '📦 MATERIAL REQUEST',
/// '⚠️ PROBLEM REPORT').
String tlInboxTypeLabel(String type) => switch (type) {
  'material' => '📦 MATERIAL REQUEST',
  'problem' => '⚠️ PROBLEM REPORT',
  _ => '🔨 WORK REQUEST',
};

/// The time on an inbox row: '09:30 AM' for today, '17 Sep, 09:30 AM' for
/// anything older (an oldest-first queue must still show *when*).
String tlInboxTimeLabel(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return DateFormat(isToday ? 'hh:mm a' : 'd MMM, hh:mm a').format(local);
}

/// The Team Leader's "Action Center": a manager's inbox of everything still
/// awaiting the gate, with the camera demoted to a floating shortcut.
///
/// Shown instead of the subcontractor's 3-button capture screen when the app is
/// launched with `--dart-define=USER_ROLE=team_leader`. Tapping a row opens the
/// shared report sheet, which resolves its own role-based bar (REMOTE / ON SITE
/// / REJECT) for every report still awaiting the gate.
class TeamLeaderHomeScreen extends StatefulWidget {
  const TeamLeaderHomeScreen({super.key, this.reportsStream});

  /// Injectable report stream (defaults to Isar's live query). Isar streams
  /// don't run in the widget-test VM, so tests pass a plain in-memory stream.
  final Stream<List<Report>>? reportsStream;

  @override
  State<TeamLeaderHomeScreen> createState() => _TeamLeaderHomeScreenState();
}

class _TeamLeaderHomeScreenState extends State<TeamLeaderHomeScreen> {
  /// True while a cloud sync is in flight (spinner shown in the app bar).
  bool _isSyncing = false;

  /// Manual sync: pushes every unsynced report to Supabase.
  Future<void> _syncReports() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Syncing...')));
    try {
      final synced = await SyncService.syncPendingReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $synced report(s)')),
      );
    } catch (e, st) {
      debugPrint('SyncFlow: TL sync failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed — check connection')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Opens the read-only history (all reports, all tabs).
  Future<void> _openHistory() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));
  }

  /// Opens the report the TL tapped. The sheet resolves its role-based bar, so
  /// every report still awaiting the gate shows the giant APPROVE / REJECT.
  Future<void> _openForValidation(Report report) {
    return showDefaultReportDetailSheet(
      context,
      report,
      role: 'team_leader',
      selfActor: 'tl',
    );
  }

  /// One inbox row: a slim card with the Sub's photo, the type request and its
  /// time, and a giant chevron that says "tap me to decide".
  Widget _inboxTile(Report report) {
    return Card(
      key: ValueKey('tl_inbox_${report.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ReportThumbnail(report: report, size: 50),
        ),
        title: Text(
          tlInboxTypeLabel(report.type),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          tlInboxTimeLabel(report.timestamp),
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        trailing: const Icon(Icons.chevron_right, size: 36),
        onTap: () => _openForValidation(report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // History is a small door in the corner: this screen is the queue.
        leading: IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'History',
          onPressed: _openHistory,
        ),
        title: const Text('Chef de Chantier'),
        actions: [
          StreamBuilder<int>(
            stream: DatabaseService.watchPendingCount(),
            initialData: 0,
            builder: (context, snapshot) {
              if (_isSyncing) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              final pending = snapshot.data ?? 0;
              if (pending > 0) {
                return IconButton(
                  icon: Badge.count(
                    count: pending,
                    child: const Icon(
                      Icons.cloud_upload,
                      color: Colors.amber,
                    ),
                  ),
                  tooltip: 'Sync to cloud',
                  onPressed: _syncReports,
                );
              }
              return IconButton(
                icon: const Icon(Icons.cloud_done, color: Colors.white),
                tooltip: 'All synced',
                onPressed: null,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Report>>(
        stream: widget.reportsStream ?? DatabaseService.watchAllReports(),
        builder: (context, snapshot) {
          // Isar emits immediately (fireImmediately); while waiting show a
          // spinner rather than a misleading empty state.
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final queue = tlInboxQueue(snapshot.data!);
          if (queue.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.coffee, size: 64, color: Colors.brown),
                  SizedBox(height: 12),
                  Text(
                    'Inbox Zero. All caught up.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 96),
            itemCount: queue.length,
            itemBuilder: (context, index) => _inboxTile(queue[index]),
          );
        },
      ),
      // The camera is a secondary action now: one floating shortcut with the
      // three types behind it, instead of three full-screen buttons.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCaptureTypeSheet(context),
        icon: const Icon(Icons.camera_alt),
        label: const Text(
          'CAPTURE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }
}
