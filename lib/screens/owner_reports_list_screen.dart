import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report.dart';
import '../widgets/report_detail_bottom_sheet.dart';
import '../widgets/report_sheet_actions.dart';
import 'owner_action_sheet.dart';
import 'owner_map_screen.dart';

// ---------------------------------------------------------------------------
// The Owner's reports list: every cloud row as one tappable card.
//
// Thin client, like the map: rows come straight from Supabase (injectable for
// tests) and are mapped onto the local [Report] model ONLY so the shared
// report sheet can render them - nothing is written to Isar. A tap opens the
// sheet with the owner's giant decisions; the Git-style timeline lives inside
// it.
// ---------------------------------------------------------------------------

/// Maps one Supabase `reports` row onto the local [Report] model, so the
/// shared report sheet (thumbnail, timeline, actions) can render it.
///
/// The row's `local_id` is carried in `report.userId` - the owner flows key
/// their Supabase writes on it, exactly like the map's decision sheet does.
Report ownerReportFromRow(Map<String, dynamic> row) {
  final events = <String>[];
  final rawEvents = row['timeline_events'];
  if (rawEvents is List) {
    for (final e in rawEvents) {
      events.add(e.toString());
    }
  }
  return Report()
    ..userId = ownerLocalIdOf(row)
    ..type = (row['type'] ?? 'work').toString()
    ..timestamp = ownerTimestampOf(row) ?? DateTime.now()
    ..photoUrl = (row['photo_url'] ?? '').toString()
    ..voiceUrl = (row['voice_url'] ?? '').toString()
    ..ownerStatus = ownerStatusOf(row)
    ..ownerStatusAt = row['owner_status_at'] != null
        ? DateTime.tryParse(row['owner_status_at'].toString())?.toLocal()
        : null
    ..tlValidationType = (row['tl_validation_type'] ?? '').toString()
    ..tlValidationPhotoUrl = (row['tl_validation_photo_url'] ?? '').toString()
    ..tlRejectionPhotoUrl = (row['tl_rejection_photo_url'] ?? '').toString()
    ..tlRejectionVoiceUrl = (row['tl_rejection_voice_url'] ?? '').toString()
    ..timelineEvents = events;
}

/// The Owner's scrollable list of every report in the cloud.
class OwnerReportsListScreen extends StatefulWidget {
  const OwnerReportsListScreen({
    super.key,
    this.reportsLoader,
    this.decisionWriter,
  });

  /// Injectable Supabase read (tests hand in a canned loader).
  final OwnerReportsLoader? reportsLoader;

  /// Injectable decision writer (tests record instead of calling the cloud).
  final OwnerDecisionWriter? decisionWriter;

  @override
  State<OwnerReportsListScreen> createState() =>
      _OwnerReportsListScreenState();
}

class _OwnerReportsListScreenState extends State<OwnerReportsListScreen> {
  /// The selected filter chip (see [ownerFilterLabels]).
  OwnerFilter _filter = OwnerFilter.all;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  /// Reads every report row straight from Supabase (no Isar). Same contract
  /// as the map screen: called on open, on refresh, and after a decision.
  Future<void> fetchReports() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await (widget.reportsLoader ?? _fetchReportsFromSupabase)();
      if (!mounted) return;
      setState(() => _rows = rows);
      _loading = false;
    } catch (e, st) {
      debugPrint('OwnerList: fetch failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the site reports.';
      });
    }
  }

  /// The one place this screen reads from the cloud.
  static Future<List<Map<String, dynamic>>> _fetchReportsFromSupabase() async {
    final rows = await Supabase.instance.client.from('reports').select();
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// The default decision writer: straight to `reports.owner_status`, keyed
  /// by `local_id` - identical to the map screen's writer.
  static Future<void> _writeDecisionToSupabase(
    String localId,
    String ownerStatus,
  ) async {
    final updated = await Supabase.instance.client
        .from('reports')
        .update({'owner_status': ownerStatus})
        .eq('local_id', localId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('No remote report with local_id=$localId');
    }
    debugPrint('OwnerList: report $localId -> owner_status=$ownerStatus');
  }

  /// Newest first (same rule as the map), so the top card is the freshest.
  List<Map<String, dynamic>> get _sortedRows {
    final sorted = [..._rows];
    sorted.sort((a, b) {
      final at = ownerTimestampOf(a);
      final bt = ownerTimestampOf(b);
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return sorted;
  }

  Future<void> _openReport(Map<String, dynamic> row) async {
    final report = ownerReportFromRow(row);
    await showReportDetailSheet(
      context,
      report: report,
      actions: ownerReportActions(
        report: report,
        writeDecision:
            widget.decisionWriter ?? _writeDecisionToSupabase,
      ),
      selfActor: 'owner',
    );
    // Re-fetch whether or not a decision was saved: the timeline may have
    // changed underneath the sheet.
    await fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sortedRows
        .where((row) => ownerRowMatchesFilter(row, _filter))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : fetchReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // The filter chips.
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final filter in OwnerFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(ownerFilterLabels[filter] ?? ''),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(rows)),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> rows) {
    if (_loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: fetchReports,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          ownerFilterLabels[_filter] == 'ALL'
              ? 'No reports yet.'
              : 'Nothing here for this filter.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: fetchReports,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final row = rows[index];
          final report = ownerReportFromRow(row);
          final status = ownerStatusOf(row);
          return ListTile(
            leading: (row['photo_url'] ?? '').toString().isEmpty
                ? const Icon(Icons.image_not_supported, size: 40)
                : Image.network(
                    (row['photo_url'] as String),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image, size: 40),
                  ),
            title: Text(
              '${ownerTypeEmoji(report.type)} ${ownerTypeLabel(report.type)} '
              '#${ownerLocalIdOf(row)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${ownerStatusWord(status)} - '
              '${ownerTlBadgeFor(report.tlValidationType).$2}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            trailing: Icon(
              ownerStatusBadgeFor(status).$1,
              color: ownerStatusBorderColor(status),
            ),
            onTap: () => _openReport(row),
          );
        },
      ),
    );
  }
}
