import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'models/report.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
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
      final reportsDir =
          await Directory('${dir.path}/reports').create(recursive: true);
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
          } catch (_) {}
        } else {
          storedPath = savedPath;
          await File(photo.path).copy(savedPath);
        }
      } catch (_) {
        // Compression unavailable: fall back to saving the raw capture.
        storedPath = savedPath;
        await File(photo.path).copy(savedPath);
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SaveReportScreen(type: type, photoPath: storedPath),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'WORK',
                color: Colors.green,
                icon: Icons.check_circle,
                iconColor: Colors.white,
                onTap: () => _onTap('work'),
              ),
            ),
            Expanded(
              child: _ActionButton(
                label: 'PROBLEM',
                color: Colors.red,
                icon: Icons.warning,
                iconColor: Colors.white,
                onTap: () => _onTap('problem'),
              ),
            ),
            Expanded(
              child: _ActionButton(
                label: 'MATERIAL',
                color: Colors.yellow.shade600,
                icon: Icons.inventory,
                iconColor: Colors.black,
                onTap: () => _onTap('material'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openHistory,
        tooltip: 'History',
        child: const Icon(Icons.history),
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
/// Displays all locally saved Reports in a scrollable list with a colored
/// status border (Yellow = pending, Green = synced).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Report>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = DatabaseService.getAllReports();
  }

  void _reload() {
    setState(() {
      _reportsFuture = DatabaseService.getAllReports();
    });
  }

  void _openReport(Report report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<Report>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? const <Report>[];
          if (reports.isEmpty) {
            return const Center(child: Text('No reports yet'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final Color borderColor =
                    report.status == 'synced' ? Colors.green : Colors.yellow;
                return InkWell(
                  onTap: () => _openReport(report),
                  child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.file(
                        File(report.photoPath),
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 160,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(report.timestamp.toLocal().toString()),
                      ),
                    ],
                  ),
                ),
);
              },
            ),
          );
        },
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
  late final AudioRecorder _recorder;
  late final AnimationController _pulseController;

  /// True while the microphone is actively recording.
  bool isRecording = false;

  /// Path of the voice note being/already recorded (null until recorded).
  String? currentVoicePath;

  Timer? _autoStopTimer;
  bool _saving = false;

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
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _onMicTap() async {
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
      final reportsDir =
          await Directory('${dir.path}/reports').create(recursive: true);
      final path =
          '${reportsDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);

      if (!mounted) return;
      setState(() {
        isRecording = true;
        currentVoicePath = path;
      });
      _pulseController.repeat(reverse: true);
      // Stop automatically after 15 seconds.
      _autoStopTimer = Timer(const Duration(seconds: 15), _stopRecording);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording failed')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!isRecording) return;
    _pulseController.stop();
    try {
      final stoppedPath = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        isRecording = false;
        // Only trust the returned path; keep the path we started with as a
        // fallback so the voice file is never lost.
        if (stoppedPath != null && stoppedPath.isNotEmpty) {
          currentVoicePath = stoppedPath;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isRecording = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (isRecording) {
      await _stopRecording();
    }
    setState(() {
      _saving = true;
    });
    try {
      final report = Report()
        ..type = widget.type
        ..photoPath = widget.photoPath
        ..voicePath = currentVoicePath ?? ''
        ..lat = 0.0
        ..lng = 0.0
        ..timestamp = DateTime.now()
        ..status = 'pending';
      await DatabaseService.saveReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved Locally')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed')),
      );
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Save Report')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                File(widget.photoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 80),
                ),
              ),
            ),
            Row(
              children: [
                // Mic button with a continuous pulse while recording.
                Expanded(
                  child: Material(
                    color: Colors.red,
                    child: InkWell(
                      onTap: _onMicTap,
                      child: SizedBox(
                        height: 160,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final t = Curves.easeInOut
                                    .transform(_pulseController.value);
                                return Transform.scale(
                                  scale: 1.0 + (0.15 * t),
                                  child: Icon(
                                    isRecording ? Icons.stop : Icons.mic,
                                    size: 80,
                                    color: Color.lerp(
                                      Colors.red,
                                      Colors.redAccent,
                                      t,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isRecording ? 'RECORDING' : 'VOICE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    label: 'SAVE',
                    color: Colors.green,
                    icon: Icons.check,
                    iconColor: Colors.white,
                    onTap: () => _save(),
                  ),
                ),
              ],
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

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Future<void> _play() async {
    final path = widget.report.voicePath;
    if (path.isEmpty || !File(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No voice note found')),
      );
      return;
    }
    try {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Play failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                File(report.photoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 80),
                ),
              ),
            ),
            if (report.voicePath.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('No voice note'),
              )
            else
              _ActionButton(
                label: 'PLAY',
                color: Colors.blue,
                icon: Icons.play_arrow,
                iconColor: Colors.white,
                onTap: () => _play(),
              ),
          ],
        ),
      ),
    );
  }
}
