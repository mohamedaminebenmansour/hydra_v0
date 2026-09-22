import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../widgets/report_thumbnail.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import '../widgets/report_sheet_actions.dart';

/// The Team Leader's "Manager's Inbox" (Chef de Chantier Dashboard).
///
/// Shown instead of the subcontractor's 3-button capture screen when the app
/// is launched with `--dart-define=USER_ROLE=team_leader`. It lists every
/// report that still awaits a gate decision (fresh 'work'/'material' reports),
/// and tapping a card opens the detail screen hosting the three validation
/// actions (validate on site / remotely / reject). The camera action routes to
/// the capture workspace so a TL can still file their own report.
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

  /// The capture workspace (the subcontractor's home): it hosts the camera
  /// capture flow that feeds [SaveReportScreen], so the TL reuses it wholesale.
  Future<void> _openCapture() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
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

  /// One pending-report row: thumbnail, type, time.
  Widget _pendingCard(Report report) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: ReportThumbnail(report: report, size: 56),
        title: Text(
          report.type == 'work' ? 'Work report' : 'Material report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('d MMM, HH:mm').format(report.timestamp.toLocal()),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openForValidation(report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chef de Chantier Dashboard'),
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
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'New report',
            onPressed: _openCapture,
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
          final pending = snapshot.data!
              .where((r) => r.needsTlValidation)
              .toList();
          if (pending.isEmpty) {
            return const Center(
              child: Text(
                'All caught up. No work pending verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pending.length,
            itemBuilder: (context, index) => _pendingCard(pending[index]),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          // Only the History tab navigates; 'To Verify' is this screen itself.
          if (index == 1) _openHistory();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'To Verify',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
