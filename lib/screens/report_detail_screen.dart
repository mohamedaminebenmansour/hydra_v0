import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/voice_equalizer.dart';
import '../widgets/voice_play_button.dart';

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
                      VoiceEqualizer(playing: _isPlaying),
                      // Always-visible thick progress bar with big time labels,
                      // so playback progress is readable outdoors.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _fmt(_position),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _duration > Duration.zero
                                    ? _position.inMilliseconds /
                                          _duration.inMilliseconds
                                    : 0.0,
                                minHeight: 12,
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.blue,
                                backgroundColor: Colors.grey.shade300,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _fmt(_duration),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      VoicePlayButton(
                        playing: _isPlaying,
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
                            DateFormat(
                              'd MMM, hh:mm a',
                            ).format(latest.timestamp.toLocal()),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Clean, tappable location row — the raw coordinates stay
                // out of sight behind the maps launcher.
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _openInMaps,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 24,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Location Captured',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
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
