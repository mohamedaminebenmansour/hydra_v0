import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Catch any button tap: immediately open the camera, then save the photo
  /// persistently with a local Report record.
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

      // Persist a Report with dummy GPS and 'pending' status.
      final report = Report()
        ..type = type
        ..photoPath = storedPath
        ..lat = 0.0
        ..lng = 0.0
        ..timestamp = DateTime.now()
        ..status = 'pending';
      await DatabaseService.saveReport(report);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved Locally')),
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
                return Card(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
