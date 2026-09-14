import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/report.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/report_local_service.dart';
import 'services/sync_service.dart';

/// SharedPreferences key holding the last time the History screen was opened.
/// Owner updates newer than this drive the red badge on the History FAB.
const String _historyLastOpenedKey = 'historyLastOpenedAtMs';

/// Formats a timestamp as 'YYYY-MM-DD HH:mm:ss' in local time.
String formatTimestamp(DateTime t) {
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${p2(t.month)}-${p2(t.day)} '
      '${p2(t.hour)}:${p2(t.minute)}:${p2(t.second)}';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yprnwybpteelfhcorwib.supabase.co',
    publishableKey: 'sb_publishable_zzeNiixC5aau8lhM8GtU6g_6GdDRPex',
  );
  await DatabaseService.init();
  await SyncService.init(); // background push on reconnect + initial pull
  await NotificationService.init(); // daily 07:00 local reminder
  runApp(const HydraApp());
}

class HydraApp extends StatelessWidget {
  const HydraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}

/// The main screen: three giant, tag-free action buttons and a history FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  /// True while a cloud sync is in flight (spinner shown in the app bar).
  bool _syncing = false;

  /// Fresh owner updates (changed after last History open, within 24h).
  /// Drives the red badge on the History FAB.
  int _freshOwnerUpdates = 0;

  @override
  void initState() {
    super.initState();
    checkOwnerUpdates();
  }

  /// Smart Pull-on-Open: pull the owner's decisions from Supabase (when
  /// online) and refresh the red badge count with setState.
  Future<void> checkOwnerUpdates() async {
    await SyncService.checkOwnerUpdates();
    await _refreshOwnerBadge();
  }

  /// Recomputes the fresh-owner-update count (changed after the last History
  /// open, within the last 24 hours) and rebuilds the FAB badge.
  Future<void> _refreshOwnerBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenedMs = prefs.getInt(_historyLastOpenedKey) ?? 0;
    final count = await DatabaseService.countFreshOwnerUpdates(
      DateTime.fromMillisecondsSinceEpoch(lastOpenedMs),
    );
    if (!mounted) return;
    setState(() => _freshOwnerUpdates = count);
  }

  /// Triggers a Supabase sync of all pending reports.
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final synced = await SyncService.syncPendingReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $synced report(s)')),
      );
    } catch (e, st) {
      debugPrint('SyncFlow: sync failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed — check connection')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Catch any button tap: immediately open the camera, compress the capture,
  /// then open the Save Report screen (voice note + confirm).
  Future<void> _onTap(String type) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null || !mounted) return; // user cancelled

      // Compress the capture down to a small JPEG (640px max, quality 70) and
      // store it persistently in the documents directory so the OS does not
      // delete it and it uploads quickly even on slow 3G networks.
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final savedPath =
          '${reportsDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      String storedPath;
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          photo.path,
          savedPath,
          minWidth: 640,
          minHeight: 640,
          quality: 70,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) {
          storedPath = compressed.path;
          // The original raw capture is no longer needed; remove it to save
          // space (best effort).
          try {
            await File(photo.path).delete();
          } catch (e, st) {
            debugPrint('ImageFlow: raw capture cleanup failed: $e\n$st');
          }
        } else {
          debugPrint(
            'ImageFlow: compressAndGetFile returned null '
            'for $savedPath — falling back to persistent copy',
          );
          storedPath =
              await ReportLocalService.persistMedia(photo.path, 'photo');
        }
      } catch (e, st) {
        // Compression unavailable: fall back to a persistent raw copy.
        debugPrint('ImageFlow: compression threw, using raw copy: $e\n$st');
        storedPath = await ReportLocalService.persistMedia(photo.path, 'photo');
      }

      // Never navigate with a photo path that does not point at a real,
      // non-empty file — otherwise the save step would persist a broken path.
      if (!await ReportLocalService.isValidFile(storedPath)) {
        debugPrint('ImageFlow: stored photo invalid: "$storedPath"');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not store photo')));
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SaveReportScreen(type: type, photoPath: storedPath),
        ),
      );
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('ImageFlow: camera flow failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera not available')));
    }
  }

  Future<void> _openHistory() async {
    // Capture the navigator before any async gap (lint-safe).
    final navigator = Navigator.of(context);
    // Stamp the open time so owner updates older than this are "seen" and
    // the red badge clears (per spec, stored in prefs).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _historyLastOpenedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    // Await the push so we can refresh the badge after returning.
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );
    if (mounted) _refreshOwnerBadge();
  }

  /// Opens a compact bottom sheet with the sync status.
  void _openSyncStatus(BuildContext context, int pendingCount) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pendingCount == 0 ? Icons.cloud_done : Icons.cloud_upload,
                size: 64,
                color: pendingCount == 0 ? Colors.green : Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                pendingCount == 0
                    ? 'All reports synced'
                    : '$pendingCount report(s) waiting to sync',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: pendingCount == 0 ? null : () => _sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
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
      appBar: AppBar(
        title: const Text('Hydra'),
        actions: [
          StreamBuilder<int>(
            stream: DatabaseService.watchPendingCount(),
            builder: (context, snapshot) {
              final pending = snapshot.data ?? 0;
              if (_syncing) {
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
              return IconButton(
                icon: Badge.count(
                  count: pending,
                  isLabelVisible: pending > 0,
                  child: Icon(
                    pending == 0 ? Icons.cloud_done : Icons.cloud_upload,
                    color: pending == 0 ? Colors.white : Colors.amber.shade300,
                  ),
                ),
                tooltip: pending == 0 ? 'All synced' : 'Sync to cloud',
                onPressed: () => _openSyncStatus(context, pending),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'WORK',
                color: Colors.blue,
                icon: Icons.handyman,
                iconColor: Colors.white,
                onTap: () => _onTap('work'),
              ),
            ),
            Expanded(
              child: _ActionButton(
                label: 'PROBLEM',
                color: Colors.red,
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.white,
                onTap: () => _onTap('problem'),
              ),
            ),
            Expanded(
              child: _ActionButton(
                label: 'MATERIAL',
                color: Colors.amber.shade600,
                icon: Icons.inventory_2,
                iconColor: Colors.white,
                onTap: () => _onTap('material'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Badge.count(
        count: _freshOwnerUpdates,
        isLabelVisible: _freshOwnerUpdates > 0,
        backgroundColor: Colors.red,
        child: FloatingActionButton(
          onPressed: _openHistory,
          tooltip: 'History',
          child: const Icon(Icons.history),
        ),
      ),
    );
  }
}

/// A single giant, full-width action button with a large icon and tiny label.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bold circular back button used on every detail / creation screen.
class BackButtonCircle extends StatelessWidget {
  const BackButtonCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
  }

  /// True when [report] belongs to the currently selected view.
  bool _matchesView(Report report) {
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

  /// Thumbnail that works offline (local file) and falls back to a network
  /// image for pulled remote records.
  Widget _reportThumb(Report report, {double size = 80}) {
    final path = report.photoPath;
    if (path.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, size: 32),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, size: 32),
        ),
      );
    }
    final exists = File(path).existsSync();
    if (!exists) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported, size: 32),
      );
    }
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: Colors.grey.shade300,
        child: const Icon(Icons.broken_image, size: 32),
      ),
    );
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

  /// One glanceable, icon-dominant report tile: 100x100 photo on the left
  /// with a status overlay (avatar + tiny caption), a giant type icon and the
  /// timestamp on the right, and the sync badge strip underneath.
  Widget _trafficCard(Report report) {
    final Widget thumb = _reportThumb(report);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openReport(report),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 100x100 photo with the status badge overlaid bottom-right.
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: thumb,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Column(
                            children: [
                              _statusAvatar(report),
                              Text(
                                _statusWord(report),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Details: giant type icon + timestamp.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_typeIcon(report), size: 40, color: _typeColor(report)),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('HH:mm').format(report.timestamp.toLocal()),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _syncBadge(report),
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
            // Segmented control: ACTIVE vs HISTORY.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
                ],
                selected: {_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
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
                          _view == 'ACTIVE'
                              ? 'No active items. All caught up!'
                              : 'No history yet.',
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

/// Shown after a photo is captured: previews the image, lets the user record an
/// optional voice note, then confirms the local Report save.
class SaveReportScreen extends StatefulWidget {
  const SaveReportScreen({
    super.key,
    required this.type,
    required this.photoPath,
  });

  final String type;
  final String photoPath;

  @override
  State<SaveReportScreen> createState() => _SaveReportScreenState();
}

class _SaveReportScreenState extends State<SaveReportScreen>
    with SingleTickerProviderStateMixin {
  late AudioRecorder _recorder;
  late final AnimationController _pulseController;

  /// True while the microphone is actively recording.
  bool isRecording = false;

  /// Seconds elapsed in the current recording (drives the live counter).
  int _recordSeconds = 0;
  Timer? _recordTicker;

  /// Path of the voice note being/already recorded (null until recorded).
  String? currentVoicePath;

  /// True once a voice note has been recorded (enables Re-record).
  bool _hasRecording = false;

  Timer? _autoStopTimer;
  bool _saving = false;

  /// True while [_stopRecording] is in flight, to prevent duplicate native
  /// stop() calls (which crash MPEG4Writer on Android).
  bool _stopping = false;

  /// Completer signalling that the in-flight stop has fully finished
  /// (including file validation). [_save] awaits this so it never validates
  /// currentVoicePath before stop() has completed.
  Completer<void>? _stopCompleter;

  /// True once the recorder instance has been disposed, so we never reuse it.
  bool _recorderDisposed = false;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    // Drives the continuous pulse of the mic icon while recording.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _pulseController.dispose();
    _recordTicker?.cancel();
    _recordTicker = null;
    // Always stop an active recording before disposing the recorder, so the
    // native encoder finalizes the file instead of crashing (MPEG4Writer).
    // Fire-and-forget: dispose() cannot be async.
    final recorder = _recorder;
    _recorderDisposed = true;
    () async {
      try {
        if (await recorder.isRecording()) {
          debugPrint('RecordFlow: dispose stopping an active recording');
          await recorder.stop();
        }
        await recorder.dispose();
      } catch (e, st) {
        // Swallow teardown races; the recorder is going away anyway.
        debugPrint('RecordFlow: teardown during dispose failed: $e\n$st');
        try {
          await recorder.dispose();
        } catch (e2, st2) {
          debugPrint(
            'RecordFlow: dispose after failure also failed: $e2\n$st2',
          );
        }
      }
    }();
    super.dispose();
  }

  /// Creates a fresh recorder instance, disposing any broken previous one.
  /// Used to recover from a wedged encoder after a failed start/stop cycle.
  void _resetRecorder() {
    if (_recorderDisposed) return;
    final old = _recorder;
    () async {
      try {
        await old.dispose();
      } catch (e, st) {
        debugPrint('RecordFlow: old recorder dispose failed: $e\n$st');
      }
    }();
    _recorder = AudioRecorder();
    debugPrint('RecordFlow: recorder instance reset after failure');
  }

  /// True only when [path] points to an existing, non-empty file.
  /// Used for both voice notes and photos.
  bool _isValidFile(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      final f = File(path);
      return f.existsSync() && f.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Waits for the voice file to appear with a non-zero size. The native
  /// MediaMuxer may still be flushing when stop() resolves, so poll briefly
  /// before declaring the recording invalid.
  Future<bool> _waitForVoiceFile(
    String? path, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (path == null || path.isEmpty) return false;
    final deadline = DateTime.now().add(timeout);
    var attempts = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempts++;
      try {
        final f = File(path);
        if (f.existsSync() && f.lengthSync() > 0) {
          debugPrint(
            'RecordFlow: voice file finalized after '
            '${attempts * 50}ms: $path',
          );
          return true;
        }
      } catch (e, st) {
        debugPrint('RecordFlow: voice file probe failed: $e\n$st');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  Future<void> _onMicTap() async {
    if (_stopping) return; // a stop is in flight; ignore taps meanwhile
    if (isRecording) {
      await _stopRecording();
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final path =
          '${reportsDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);

      if (!mounted) return;
      setState(() {
        isRecording = true;
        _recordSeconds = 0;
        currentVoicePath = path;
      });
      _pulseController.repeat(reverse: true);
      // Live recording counter.
      _recordTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _recordSeconds++),
      );
      // Stop automatically after 15 seconds.
      _autoStopTimer = Timer(const Duration(seconds: 15), _stopRecording);
    } catch (e, st) {
      // The recorder instance may be wedged; recreate it so the next tap can
      // start a fresh session instead of failing forever.
      debugPrint('RecordFlow: recording start failed: $e\n$st');
      _resetRecorder();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recording failed')));
    }
  }

  Future<void> _stopRecording() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _recordTicker?.cancel();
    _recordTicker = null;
    if (_stopping || !isRecording) return;
    _stopping = true;
    _stopCompleter = Completer<void>();
    _pulseController.stop();
    try {
      // Ask the plugin for the authoritative native state BEFORE stopping.
      // If it already stopped (e.g. a prior stop raced with the auto-stop
      // timer), calling stop() again would crash MPEG4Writer on Android.
      bool activelyRecording = false;
      try {
        activelyRecording = await _recorder.isRecording();
      } catch (e, st) {
        debugPrint('RecordFlow: isRecording() probe failed: $e\n$st');
      }
      if (!activelyRecording) {
        if (!mounted) return;
        setState(() {
          isRecording = false;
        });
        return;
      }
      final stoppedPath = await _recorder.stop();
      // Give the native muxer a moment to flush; a 0-byte file right after
      // stop() often finalizes within a few hundred milliseconds.
      final stoppedValid = await _waitForVoiceFile(stoppedPath);
      final fallbackValid = stoppedValid
          ? false
          : await _waitForVoiceFile(currentVoicePath);
      if (!mounted) return;
      setState(() {
        isRecording = false;
        // Only trust a path that now points at a real, non-empty file.
        // Otherwise clean up so nothing broken is persisted.
        if (stoppedValid) {
          currentVoicePath = stoppedPath;
          _hasRecording = true;
        } else if (fallbackValid) {
          // Keep the started path (already set) — stop() returned nothing
          // useful but the started file is intact.
          debugPrint(
            'RecordFlow: stop() path invalid, keeping started '
            'voice file: "$currentVoicePath"',
          );
          _hasRecording = true;
        } else {
          debugPrint(
            'RecordFlow: no valid voice file after stop '
            '(stopped: "$stoppedPath", started: "$currentVoicePath")',
          );
          for (final p in [stoppedPath, currentVoicePath]) {
            if (p != null && p.isNotEmpty) {
              try {
                final f = File(p);
                if (f.existsSync()) f.deleteSync();
              } catch (e, st) {
                debugPrint('RecordFlow: broken voice cleanup failed: $e\n$st');
              }
            }
          }
          currentVoicePath = null;
          _hasRecording = false;
        }
      });
    } catch (e, st) {
      debugPrint('RecordFlow: recorder stop failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        isRecording = false;
        _hasRecording = false;
      });
    } finally {
      _stopping = false;
      _stopCompleter?.complete();
      _stopCompleter = null;
    }
  }

  /// Discard the current voice note and start a fresh recording.
  Future<void> _reRecord() async {
    final old = currentVoicePath;
    setState(() {
      currentVoicePath = null;
      _hasRecording = false;
      _recordSeconds = 0;
    });
    if (old != null && old.isNotEmpty) {
      try {
        final f = File(old);
        if (f.existsSync()) f.deleteSync();
      } catch (e, st) {
        debugPrint('RecordFlow: re-record cleanup failed: $e\n$st');
      }
    }
    await _onMicTap();
  }

  Future<void> _save() async {
    if (_saving) return;
    // Wait for any in-flight stop to fully finish FIRST. Without this, a
    // stop-then-immediately-save sequence validated currentVoicePath before
    // stop() completed and silently saved a photo-only report ("No voice
    // note") even though the .m4a file finalized on disk moments later.
    if (_stopCompleter != null) {
      await _stopCompleter!.future;
    } else if (isRecording) {
      await _stopRecording();
    }
    setState(() {
      _saving = true;
    });
    try {
      // GPS position: 0.0 on disabled services, denied permission, or
      // failure. The OS permission dialog is only shown when needed.
      double lat = 0.0;
      double lng = 0.0;
      try {
        if (!await Geolocator.isLocationServiceEnabled()) {
          debugPrint('LocationFlow: location services disabled — using 0.0');
        } else {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            debugPrint('LocationFlow: permission=$permission — using 0.0');
          } else {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
            lat = pos.latitude;
            lng = pos.longitude;
            debugPrint('LocationFlow: position acquired lat=$lat lng=$lng');
          }
        }
      } catch (e, st) {
        debugPrint('LocationFlow: position failed, using 0.0: $e\n$st');
      }

      // Device model as mobileId, e.g. "samsung SM-A035F".
      String mobileId = '';
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        mobileId = '${info.manufacturer} ${info.model}'.trim();
        debugPrint('DeviceFlow: mobileId="$mobileId"');
      } catch (e, st) {
        debugPrint('DeviceFlow: androidInfo failed: $e\n$st');
      }

      // Re-validate the voice file at save time: if the recording was
      // interrupted (e.g. app backgrounded and lost focus), the file may not
      // exist or may be empty. Save a photo-only report rather than a broken
      // path in the database.
      if (!_isValidFile(currentVoicePath)) {
        debugPrint(
          'SaveFlow: voice file invalid, saving photo-only report '
          '(path was: "$currentVoicePath")',
        );
        currentVoicePath = null;
      }
      // Symmetric validation for the photo: it is mandatory, so block the
      // save entirely if the file is missing or empty instead of persisting
      // a broken path to Isar.
      if (!_isValidFile(widget.photoPath)) {
        debugPrint(
          'SaveFlow: photo file invalid, blocking save '
          '(path was: "${widget.photoPath}")',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo file missing, cannot save')),
        );
        setState(() {
          _saving = false;
        });
        return;
      }
      final report = Report()
        ..type = widget.type
        ..photoPath = widget.photoPath
        ..voicePath = currentVoicePath ?? ''
        ..lat = lat
        ..lng = lng
        ..userId = 'tl_1'
        ..mobileId = mobileId
        ..timestamp = DateTime.now()
        ..status = 'local'
        ..photoStatus = 'pending'
        ..voiceStatus = 'pending'
        ..dbStatus = 'pending';
      final savedId = await ReportLocalService.saveReport(report);
      debugPrint('SaveFlow: report persisted with Isar id=$savedId');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved Locally')));
      Navigator.of(context).pop();
      // Offline-first: attempt an immediate background push of the new
      // report (no-ops offline; auto-retries on connectivity restore).
      unawaited(SyncService.syncPendingReports());
    } catch (e, st) {
      debugPrint('SaveFlow: Isar saveReport failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Save failed')));
      setState(() {
        _saving = false;
      });
    }
  }

  String _fmtSecs(int s) {
    final m = (s ~/ 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonCircle(),
        title: const Text('Save Report'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Image.file(
                File(widget.photoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 80),
                ),
              ),
            ),
            // Mic zone: ripple rings while recording, re-record pill after.
            Expanded(
              flex: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                color: isRecording ? Colors.red.shade700 : Colors.grey.shade900,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isRecording) ...[
                      SizedBox(
                        height: 180,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final t = Curves.easeInOut
                                  .transform(_pulseController.value);
                              return SizedBox(
                                width: 180,
                                height: 180,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 80 + 80 * t,
                                      height: 80 + 80 * t,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.15 * (1 - t)),
                                      ),
                                    ),
                                    Container(
                                      width: 60 + 40 * t,
                                      height: 60 + 40 * t,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.18 * (1 - t)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _stopRecording,
                                      child: CircleAvatar(
                                        radius: 44,
                                        backgroundColor: Colors.white,
                                        child: Icon(Icons.stop, size: 56,
                                            color: Colors.red.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fmtSecs(_recordSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'TAP TO STOP',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _onMicTap,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: _hasRecording
                                  ? Colors.blue.shade700
                                  : Colors.white24,
                              child: Icon(
                                _hasRecording ? Icons.mic : Icons.mic_none,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hasRecording ? 'VOICE OK' : 'ADD VOICE NOTE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (_hasRecording) ...[
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _reRecord,
                                icon: const Icon(Icons.replay,
                                    color: Colors.white70, size: 20),
                                label: const Text(
                                  'Re-record',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Giant green DONE button at the bottom.
            SizedBox(
              height: 120,
              child: Material(
                color: Colors.green,
                child: InkWell(
                  onTap: () => _save(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 56,
                            color: _hasRecording
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(height: 4),
                        const Text(
                          'DONE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}

/// Shows a single Report with the photo and a play button for its voice note.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.report});

  final Report report;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with WidgetsBindingObserver {
  /// Latest copy of the report, refreshed from Isar on focus changes.
  late Report _report;
  late Future<Report?> _reportFuture;

  /// Audio player + visual feedback state. Created once, reused for every
  /// play/pause; disposed with the screen.
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _report = widget.report;
    _reportFuture = DatabaseService.getReportById(widget.report.id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-fetch the record from Isar when the screen regains focus, so the
    // photo/voice paths shown are always the latest stored values.
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _reportFuture = DatabaseService.getReportById(widget.report.id);
      });
    }
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Opens the report's GPS coordinates in the external maps launcher.
  Future<void> _openInMaps() async {
    final lat = _report.lat;
    final lng = _report.lng;
    if (lat == 0 && lng == 0) return;
    try {
      // Google Maps query URL, opened in the system browser/maps app.
      await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      debugPrint('MapFlow: open failed: $e\n$st');
    }
  }

  /// Toggle playback. Creates (once) and subscribes to a persistent player so
  /// the UI can animate while audio is active and reset when it finishes.
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player?.pause();
      return;
    }
    final path = _report.voicePath;
    if (path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No voice note')));
      return;
    }
    if (!File(path).existsSync()) {
      debugPrint('PlaybackFlow: voicePath set but file missing: "$path"');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice file missing')));
      return;
    }
    try {
      final created = _player == null;
      final player = _player ??= AudioPlayer();
      if (created) _attachPlayer(player);
      await player.setReleaseMode(ReleaseMode.stop);
      // After a track finished, restart from the beginning.
      if (_duration > Duration.zero && _position >= _duration) {
        await player.seek(Duration.zero);
        _position = Duration.zero;
      }
      await player.play(DeviceFileSource(path));
    } catch (e, st) {
      debugPrint('PlaybackFlow: play failed for "$path": $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Play failed')));
    }
  }

  /// Lazily attaches the streams of a freshly created player.
  void _attachPlayer(AudioPlayer player) {
    _posSub = player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _position = d);
    });
    _durSub = player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _stateSub = player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _position = _duration; // show a full bar while it settles back
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButtonCircle(),
        title: const Text('Report'),
      ),
      body: SafeArea(
        child: FutureBuilder<Report?>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final Report? latest = snapshot.data;
            if (latest == null) {
              // The record was deleted (or the id is no longer valid).
              return const Center(child: Text('Report no longer exists'));
            }
            // Use the fresh Isar record (latest paths), falling back to the
            // widget-supplied snapshot only for the very first frame.
            _report = latest;
            return Column(
              children: [
                Expanded(
                  child: Image.file(
                    File(latest.photoPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 80),
                    ),
                  ),
                ),
                if (latest.voicePath.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No voice note'),
                  )
                else
                  Column(
                    children: [
                      _VoiceEqualizer(playing: _isPlaying),
                      AnimatedOpacity(
                        opacity: _isPlaying ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(_fmt(_position)),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: _duration > Duration.zero
                                      ? _position.inMilliseconds /
                                            _duration.inMilliseconds
                                      : 0.0,
                                ),
                              ),
                              Text(_fmt(_duration)),
                            ],
                          ),
                        ),
                      ),
                      _ActionButton(
                        label: _isPlaying ? 'PAUSE' : 'PLAY',
                        color: Colors.blue,
                        icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                        iconColor: Colors.white,
                        onTap: () => _togglePlay(),
                      ),
                    ],
                  ),
Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatTimestamp(latest.timestamp.toLocal()),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${latest.lat}, Lng: ${latest.lng}',
                          ),
                        ),
                        if (latest.lat != 0 || latest.lng != 0)
                          IconButton(
                            icon: const Icon(Icons.map),
                            tooltip: 'Open in Maps',
                            onPressed: _openInMaps,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Animated 5-bar equalizer that moves only while audio is playing and
/// settles to a flat row when idle.
class _VoiceEqualizer extends StatefulWidget {
  const _VoiceEqualizer({required this.playing});

  final bool playing;

  @override
  State<_VoiceEqualizer> createState() => _VoiceEqualizerState();
}

class _VoiceEqualizerState extends State<_VoiceEqualizer>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: 48,
          child: Align(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                final phase = (_controller.value + i * 0.19) % 1.0;
                // Triangle-wave in [0,1]: peaks in the middle of the cycle.
                final wave = 1.0 - (phase - 0.5).abs() * 2;
                final factor = widget.playing ? 0.30 + 0.70 * wave : 0.25;
                return Container(
                  width: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 44 * factor,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(
                      alpha: widget.playing ? 1.0 : 0.4,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

