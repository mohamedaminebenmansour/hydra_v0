import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/report.dart';
import '../services/report_local_service.dart';
import '../services/sync_service.dart';
import '../widgets/back_button_circle.dart';

/// Shown after a photo is captured: previews the image, lets the user record an
/// optional voice note, then confirms the local Report save.
///
/// Exception — the **material request** (`type == 'material'`): no photo is
/// ever forced (the home flow skips the camera for this type), the screen shows
/// one giant mic labelled 'RECORD YOUR REQUEST', the voice note is mandatory
/// and the photo is optional via the smaller '📷 Add Photo (Optional)' button.
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

  /// "Material Request" only: path of the OPTIONAL photo captured from this
  /// screen (the forced capture flow never runs for 'material'). Empty when
  /// the request stays voice-only.
  String _materialPhotoPath = '';

  /// Selected problem category for problem-type reports.
  String? _problemCategory;

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

  /// "Material Request": the OPTIONAL photo. Opens the camera on demand and
  /// stores a compressed persistent copy exactly like the forced
  /// work/problem capture, so an optional photo still uploads fast on 3G.
  /// Re-tapping replaces (and cleans up) the previous capture.
  Future<void> _addOptionalMaterialPhoto() async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (photo == null || !mounted) return; // user cancelled
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
        storedPath =
            compressed?.path ??
            await ReportLocalService.persistMedia(photo.path, 'photo');
      } catch (e, st) {
        debugPrint('SaveFlow: optional photo compress failed: $e\n$st');
        storedPath = await ReportLocalService.persistMedia(photo.path, 'photo');
      }
      if (!await ReportLocalService.isValidFile(storedPath)) {
        debugPrint('SaveFlow: optional photo invalid: "$storedPath"');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not store photo')),
        );
        return;
      }
      final previous = _materialPhotoPath;
      if (!mounted) return;
      setState(() => _materialPhotoPath = storedPath);
      if (previous.isNotEmpty && previous != storedPath) {
        try {
          final old = File(previous);
          if (old.existsSync()) old.deleteSync();
        } catch (e, st) {
          debugPrint('SaveFlow: old optional photo cleanup failed: $e\n$st');
        }
      }
    } catch (e, st) {
      debugPrint('SaveFlow: optional photo capture failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera not available')));
    }
  }

  /// Drops the optional material photo (and its file) — the request goes back
  /// to being voice-only.
  void _removeOptionalMaterialPhoto() {
    final old = _materialPhotoPath;
    setState(() => _materialPhotoPath = '');
    if (old.isEmpty) return;
    try {
      final f = File(old);
      if (f.existsSync()) f.deleteSync();
    } catch (e, st) {
      debugPrint('SaveFlow: optional photo cleanup failed: $e\n$st');
    }
  }

  /// Builds the problem category picker: 4 generously spaced icon circles,
  /// laid out in a Wrap so they have room to breathe and are easy to hit.
  Widget _buildProblemCategoryRow() {
    final categories = [
      {'icon': Icons.build, 'color': Colors.red, 'value': 'machine', 'label': 'Machine'},
      {'icon': Icons.inventory, 'color': Colors.amber, 'value': 'material_missing', 'label': 'Material'},
      {'icon': Icons.terrain, 'color': Colors.brown, 'value': 'soil', 'label': 'Soil/Rock'},
      {'icon': Icons.person_off, 'color': Colors.blue, 'value': 'external', 'label': 'External'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16.0,
        runSpacing: 16.0,
        children: categories.map((cat) {
          final isSelected = _problemCategory == cat['value'];
          final color = cat['color'] as Color;
          // Selected = solid colored circle (e.g. Amber for Material) so the
          // active category is instantly obvious. The ink flips to stay
          // readable on top of the fill.
          final selectedInk =
              ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black87;
          return GestureDetector(
            onTap: () =>
                setState(() => _problemCategory = cat['value'] as String),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : null,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? color
                          : color.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    cat['icon'] as IconData,
                    size: 40,
                    color: isSelected ? selectedInk : color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
      // Validate the two media BEFORE any platform probe (GPS, device info):
      // a blocked save must fail fast with its exact message instead of making
      // the user wait for a location fix first.
      //
      // Voice note: optional for work/problem (a photo-only report is legal),
      // MANDATORY for the material request — the recording IS the request, so
      // without it there is nothing to save.
      if (!_isValidFile(currentVoicePath)) {
        if (widget.type == 'material') {
          debugPrint('SaveFlow: material request without a voice note — '
              'blocking save');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice note required')),
          );
          setState(() {
            _saving = false;
          });
          return;
        }
        debugPrint(
          'SaveFlow: voice file invalid, saving photo-only report '
          '(path was: "$currentVoicePath")',
        );
        currentVoicePath = null;
      }
      // Photo: mandatory for work/problem, OPTIONAL for the material request
      // (captured from this screen through '📷 Add Photo (Optional)'; an empty
      // path is persisted as ''). Either way a broken path never reaches Isar.
      var photoPath = widget.type == 'material'
          ? _materialPhotoPath
          : widget.photoPath;
      if (!_isValidFile(photoPath)) {
        if (widget.type != 'material') {
          debugPrint(
            'SaveFlow: photo file invalid, blocking save '
            '(path was: "$photoPath")',
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
        debugPrint(
          'SaveFlow: material request has no photo — saving with an empty '
          'photoPath (was: "$photoPath")',
        );
        photoPath = '';
      }
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

      final report = Report()
        ..type = widget.type
        ..photoPath = photoPath
        ..voicePath = currentVoicePath ?? ''
        ..lat = lat
        ..lng = lng
        ..userId = 'tl_1'
        ..mobileId = mobileId
        ..timestamp = DateTime.now()
        ..status = 'local'
        ..photoStatus = 'pending'
        ..voiceStatus = 'pending'
        ..dbStatus = 'pending'
        ..problemCategory = _problemCategory ?? 'general'
        ..addTimelineEvent(
          actor: 'sub',
          action: 'submit',
          photoPath: photoPath,
          voicePath: currentVoicePath ?? '',
        );
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
            // Photo preview — work/problem only. The material request is
            // voice-only (photoPath is ''), so there is no image to show and
            // the mic zone below gets the whole space instead.
            if (widget.type != 'material') ...[
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
            ],
            // Problem category selection (only for problem-type reports).
            if (widget.type == 'problem') ...[
              const SizedBox(height: 12),
              const Text(
                'Problem Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildProblemCategoryRow(),
              const SizedBox(height: 12),
            ],
            // "Material Request": the giant mic stays the star; the photo is
            // optional — one smaller secondary button opens the camera, and a
            // thumbnail + remove appear once something was captured.
            if (widget.type == 'material') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_materialPhotoPath.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_materialPhotoPath),
                          height: 96,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 96,
                            child: Icon(Icons.broken_image, size: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addOptionalMaterialPhoto,
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: const Text('📷 Add Photo (Optional)'),
                      ),
                    ),
                    if (_materialPhotoPath.isNotEmpty)
                      TextButton(
                        onPressed: _removeOptionalMaterialPhoto,
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
              ),
            ],
            // Mic zone: ripple rings while recording, re-record pill after.
            Expanded(
              flex: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                color: isRecording ? Colors.red.shade400 : Colors.grey.shade900,
                width: double.infinity,
                // BoxFit.scaleDown keeps the whole mic control visible on
                // short screens; it never scales up, so tall phones keep the
                // giant look and small ones never overflow.
                child: FittedBox(fit: BoxFit.scaleDown, child: Column(
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
                                            color: Colors.red.shade400),
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
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
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
                              _hasRecording
                                  ? 'VOICE OK'
                                  : widget.type == 'material'
                                      ? 'RECORD YOUR REQUEST'
                                      : 'ADD VOICE NOTE',
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
