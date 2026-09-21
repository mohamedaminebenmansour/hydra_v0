import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/report_detail_bottom_sheet.dart';
import '../widgets/report_sheet_actions.dart';
import '../widgets/traffic_card.dart';
import 'owner_action_sheet.dart';
import 'owner_map_screen.dart';

// ---------------------------------------------------------------------------
// The Owner's Executive List: "Audit & Reports".
//
// Thin client, like the map: rows come straight from Supabase (injectable for
// tests) and are mapped onto the local [Report] model ONLY so the shared
// TrafficCard / report sheet can render them - nothing is written to Isar.
// Every card is grouped under its day (TODAY / YESTERDAY / long date), which
// is what makes the list usable for auditing and payment preparation. A tap
// opens the report detail sheet with the owner's giant decisions; the
// Git-style timeline lives inside it.
// ---------------------------------------------------------------------------

// `ownerReportFromRow` lives in `owner_action_sheet.dart` with the other
// raw-row helpers, so the map and this list always map a row identically.

/// The Executive List's five filter chips, in display order. The MAP screen
/// shares the [OwnerFilter] values but shows its own (shorter) labels, so
/// each surface keeps its own wording without breaking the other.
const List<OwnerFilter> ownerListFilters = [
  OwnerFilter.all,
  OwnerFilter.myActions,
  OwnerFilter.problems,
  OwnerFilter.material,
  OwnerFilter.rework,
];

/// Labels of the Executive List's filter chips (see [ownerListFilters]).
const Map<OwnerFilter, String> ownerListFilterLabels = {
  OwnerFilter.all: 'All',
  OwnerFilter.myActions: '🔥 Pending My Action',
  OwnerFilter.problems: '⚠️ Problems',
  OwnerFilter.material: '📦 Material',
  OwnerFilter.rework: '🔧 Rework',
};

/// The Owner's Executive List: every report in the cloud, grouped by day,
/// with five audit filters — the payment-preparation counterpart to the map.
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
        title: const Text('Audit & Reports'),
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
          // The Executive List's five audit filter chips.
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final filter in ownerListFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(ownerListFilterLabels[filter] ?? ''),
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
          ownerListFilterLabels[_filter] == 'All'
              ? 'No reports yet.'
              : 'Nothing here for this filter.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: fetchReports,
      child: _buildGroupedList(rows),
    );
  }

  /// The Executive List body: the (already newest-first) rows grouped under
  /// day headers — 'TODAY', 'YESTERDAY', then long dates — and flattened into
  /// one [ListView.builder] of header items and [TrafficCard] items. Each card
  /// carries the TL Visual Badge (On Site vs Remote vs Rejected) and the
  /// owner-status colouring; a tap opens the report detail sheet.
  Widget _buildGroupedList(List<Map<String, dynamic>> rows) {
    // Group by day, preserving the newest-first order within each group.
    final headers = <String>[];
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final ts = ownerTimestampOf(row);
      // Rows without a parsable timestamp cannot be dated; bucket them under
      // a trailing 'UNDATED' header instead of dropping them.
      final label = ts == null ? 'UNDATED' : dayGroupLabel(ts);
      if (!byDay.containsKey(label)) {
        byDay[label] = <Map<String, dynamic>>[];
        headers.add(label);
      }
      byDay[label]!.add(row);
    }

    // Flatten into header + card entries for a single scrollable list.
    final entries = <Widget>[];
    for (final label in headers) {
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
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
      for (final row in byDay[label]!) {
        final report = ownerReportFromRow(row);
        entries.add(
          TrafficCard(
            key: ValueKey('owner_list_card_${ownerLocalIdOf(row)}'),
            report: report,
            showUnreadDot: false,
            onTap: () => _openReport(row),
          ),
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) => entries[index],
    );
  }
}
