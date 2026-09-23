import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'notify_gate.dart';

// ---------------------------------------------------------------------------
// "Material Reception" capture: the two-step sheet the field team walks through
// when an ordered delivery arrives.
//
//   Step 1 (auto-camera): the camera opens the moment the sheet appears; the
//                   sheet then shows the thumbnail with the two giant verdicts
//                   right below it: [ACCEPT ALL] (green) / [REPORT ISSUE] (red).
//   Step 2 (voice, ONLY when reporting an issue): the microphone, then the
//                   giant [CONFIRM ISSUE]. The happy path never asks for a
//                   voice note: Receive -> Camera -> Accept = 3 clicks.
//
// A pure capture surface: it never touches Isar, never pushes to the cloud and
// returns what it captured ([MaterialReceptionResult]) so the flow that opened
// it owns the local write. Cancelling at any step deletes the files it already
// created, so an abandoned reception leaves the report — and the disk — exactly
// as they were.
// ---------------------------------------------------------------------------

/// What the reception sheet captured: the two media paths and the binary
/// verdict the field team took.
typedef MaterialReceptionResult = ({
  String photoPath,
  String voicePath,
  bool accepted,
});

/// Opens the reception capture sheet (auto-camera + binary verdict). Returns
/// null when the user cancels, in which case the report is left untouched.
/// [cameraSource] overrides the camera pipeline (tests).
Future<MaterialReceptionResult?> showMaterialReceptionSheet(
  BuildContext context, {
  Future<String?> Function()? cameraSource,
}) {
  return showModalBottomSheet<MaterialReceptionResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => MaterialReceptionSheet(cameraSource: cameraSource),
  );
}

/// 'RECEIVE MATERIAL': captures the delivery photo and voice note, then writes
/// the binary verdict through [DatabaseService.markMaterialReceived] and fires
/// the cloud push (offline-first: the write is local, the push is retried on the
/// next trigger).
///
/// Returns true when the report changed, so the sheet that injected this flow
/// (its `ReportActionCallback`) closes itself; a cancelled capture returns
/// false and nothing is written. The flow lives here — next to the capture
/// sheet it opens — so `report_detail_bottom_sheet.dart` and
/// `report_sheet_actions.dart` can both run it without an import cycle.
Future<bool> materialReceptionFlow(BuildContext context, Report report) async {
  try {
    if (!context.mounted) return false;
    final captured = await showMaterialReceptionSheet(context);
    if (captured == null) {
      debugPrint('ReceptionFlow: report ${report.id} reception cancelled');
      return false;
    }
    report.receptionPhotoPath = captured.photoPath;
    report.receptionVoicePath = captured.voicePath;
    await DatabaseService.markMaterialReceived(
      report,
      accepted: captured.accepted,
    );
    debugPrint(
      'ReceptionFlow: report ${report.id} '
      '${captured.accepted ? 'accepted' : 'issue reported'}',
    );
    if (!context.mounted) return true;
    notifyGate(
      context,
      captured.accepted
          ? 'Material received'
          : 'Delivery issue reported to the Owner',
    );
    // Offline-first: no-ops offline and is retried on the next sync trigger.
    unawaited(SyncService.syncPendingReports());
    return true;
  } catch (e, st) {
    debugPrint('ReceptionFlow: reception failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(context, 'Reception failed');
    return false;
  }
}

/// The reception capture sheet itself (see [showMaterialReceptionSheet]).
class MaterialReceptionSheet extends StatefulWidget {
  const MaterialReceptionSheet({super.key, this.cameraSource});

  /// Test seam: returns the raw captured photo path (null/empty = the user
  /// cancelled the camera). When null — the production default — the real
  /// ImagePicker camera pipeline runs.
  final Future<String?> Function()? cameraSource;

  @override
  State<MaterialReceptionSheet> createState() => _MaterialReceptionSheetState();
}

class _MaterialReceptionSheetState extends State<MaterialReceptionSheet> {
  final ImagePicker _picker = ImagePicker();

  /// The recorder, created on first use: merely opening the sheet never touches
  /// the microphone plugin, so the two-step surface stays testable (and a user
  /// who cancels at step 1 never prompts for the microphone at all).
  AudioRecorder? _recorder;

  AudioRecorder get _mic => _recorder ??= AudioRecorder();

  /// 0 = auto-camera delivery photo + the binary verdict (the happy path
  /// lives entirely here); 1 = the issue-only voice note.
  int _step = 0;
  String _photoPath = '';
  String _voicePath = '';
  bool _recording = false;
  int _seconds = 0;
  bool _busy = false;
  Timer? _ticker;
  Timer? _autoStop;

  @override
  void initState() {
    super.initState();
    // Spec Step 1 (Auto-Camera): the camera opens the moment the sheet
    // appears — ONE shot only; a cancelled camera leaves the verdicts
    // disabled instead of nagging with a second prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_takePhoto());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoStop?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  /// `<documents>/reports` — the permanent folder every capture lives in, so an
  /// offline reception survives OS cache cleaning.
  Future<Directory> _reportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/reports').create(recursive: true);
  }

  /// The production camera pipeline: the OS camera, then a compressed
  /// persistent JPEG (light enough for a slow link). Falls back to the raw
  /// capture when compression is unavailable.
  Future<String?> _cameraCapture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return null; // user cancelled
    try {
      final reportsDir = await _reportsDir();
      final savedPath =
          '${reportsDir.path}/reception_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        photo.path,
        savedPath,
        minWidth: 640,
        minHeight: 640,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      return compressed?.path ?? photo.path;
    } catch (e, st) {
      debugPrint('ReceptionFlow: photo compress skipped: $e\n$st');
      return photo.path;
    }
  }

  /// Step 1 (auto-camera): adopt whatever the capture pipeline produced as
  /// the thumbnail the verdicts act on.
  /// [MaterialReceptionSheet.cameraSource] stands in for that whole pipeline
  /// (tests) and returns an already-final path.
  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String? finalPath = widget.cameraSource != null
          ? await widget.cameraSource!()
          : await _cameraCapture();
      if (finalPath == null || finalPath.isEmpty) return; // user cancelled
      final previous = _photoPath;
      if (!mounted) return;
      setState(() => _photoPath = finalPath);
      // A retake replaces the previous capture: never leave an orphan behind.
      if (previous.isNotEmpty && previous != finalPath) {
        await _deleteQuietly(previous);
      }
      debugPrint('ReceptionFlow: reception photo stored at $finalPath');
    } catch (e, st) {
      debugPrint('ReceptionFlow: photo capture failed: $e\n$st');
      if (mounted) _notify('Photo capture failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Step 2: mic on/off. A 15-second cap keeps the note short and the upload
  /// small, exactly like the report and rejection voice notes.
  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    try {
      if (!await _mic.hasPermission()) {
        debugPrint('ReceptionFlow: microphone permission denied');
        if (mounted) _notify('Microphone permission required');
        return;
      }
      final reportsDir = await _reportsDir();
      final path =
          '${reportsDir.path}/reception_voice_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _mic.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _seconds++),
      );
      _autoStop = Timer(const Duration(seconds: 15), _stopRecording);
    } catch (e, st) {
      debugPrint('ReceptionFlow: voice recording failed: $e\n$st');
      if (mounted) _notify('Recording failed');
    }
  }

  /// Stops the recorder and waits for the muxer to flush a non-empty file (the
  /// same probe the rejection recorder uses) before adopting the path.
  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _autoStop?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    try {
      final stopped = await _mic.stop();
      var valid = false;
      if (stopped != null) {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          try {
            final file = File(stopped);
            if (file.existsSync() && file.lengthSync() > 0) {
              valid = true;
              break;
            }
          } catch (e, st) {
            debugPrint('ReceptionFlow: voice file probe failed: $e\n$st');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      if (!mounted) return;
      if (!valid) {
        setState(() => _voicePath = '');
        return;
      }
      final previous = _voicePath;
      setState(() => _voicePath = stopped!);
      // A re-record replaces the previous note.
      if (previous.isNotEmpty && previous != stopped) {
        await _deleteQuietly(previous);
      }
      debugPrint('ReceptionFlow: reception voice stored at $stopped');
    } catch (e, st) {
      debugPrint('ReceptionFlow: voice stop failed: $e\n$st');
    }
  }

  /// Closes the sheet with the binary verdict: ACCEPT ALL (accepted — the
  /// happy path, NO voice ever asked, `voicePath` always '') or CONFIRM ISSUE
  /// (the delivery dispute, whose voice note is mandatory to explain it).
  Future<void> _finish(bool accepted) async {
    if (_busy || _photoPath.isEmpty) return;
    // An issue must be explained: the recorded voice is its mandatory proof.
    if (!accepted && _voicePath.isEmpty) return;
    setState(() => _busy = true);
    await _stopRecording();
    if (!mounted) return;
    Navigator.of(context).pop((
      photoPath: _photoPath,
      voicePath: accepted ? '' : _voicePath,
      accepted: accepted,
    ));
  }

  /// Aborts the reception: stops the recorder, deletes what was captured and
  /// pops null so the report stays exactly as it was.
  Future<void> _cancel() async {
    _ticker?.cancel();
    _autoStop?.cancel();
    try {
      if (_recording) await _mic.stop();
    } catch (e, st) {
      debugPrint('ReceptionFlow: cancel stop failed: $e\n$st');
    }
    if (_photoPath.isNotEmpty) await _deleteQuietly(_photoPath);
    if (_voicePath.isNotEmpty) await _deleteQuietly(_voicePath);
    if (mounted) Navigator.of(context).pop();
  }

  /// Deletes [path] when it exists; every failure is logged and swallowed so an
  /// aborted capture can never crash the sheet.
  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, st) {
      debugPrint('ReceptionFlow: delete skipped for "$path": $e\n$st');
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: _step == 0 ? _photoStep() : _voiceStep(),
        ),
      ),
    );
  }

  /// Step 1 (auto-camera) — the delivery photo with the binary verdict right
  /// below it: the happy path is Receive -> Camera -> Accept, three clicks.
  /// The voice note is NEVER asked here — only the issue branch has one.
  Widget _photoStep() {
    final hasPhoto = _photoPath.isNotEmpty;
    final canDecide = hasPhoto && !_busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DELIVERY PHOTO',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          hasPhoto
              ? 'Photograph what arrived — accept it, or report the problem.'
              : 'Photograph what arrived: the material, the quantity, any damage.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_photoPath),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 180,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          )
        else
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Camera cancelled — take a photo to continue.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Secondary control: the fallback when the auto-camera was cancelled,
        // or a retake. Never on the happy path, so it costs no extra clicks.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _takePhoto,
            icon: Icon(hasPhoto ? Icons.refresh : Icons.camera_alt, size: 18),
            label: Text(hasPhoto ? 'RETAKE PHOTO' : 'TAKE PHOTO'),
          ),
        ),
        const SizedBox(height: 12),
        // Spec Step 2 (The Binary Choice): two giant buttons side by side,
        // directly below the photo.
        Row(
          children: [
            Expanded(
              child: _verdictButton(
                label: 'ACCEPT ALL',
                icon: Icons.check_circle,
                color: Colors.green.shade700,
                enabled: canDecide,
                onTap: () => _finish(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _verdictButton(
                label: 'REPORT ISSUE',
                icon: Icons.report_problem,
                color: Colors.red.shade700,
                enabled: canDecide,
                onTap: () => setState(() => _step = 1),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel reception'),
        ),
      ],
    );
  }

  /// Step 2 — ONLY reached by 'REPORT ISSUE': the voice note is mandatory to
  /// explain the problem, then the giant 'CONFIRM ISSUE' closes the dispute.
  Widget _voiceStep() {
    final hasVoice = _voicePath.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'REPORT ISSUE — VOICE NOTE',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          hasVoice
              ? 'Explanation recorded — confirm to report the issue.'
              : 'Say what is wrong with the delivery (required).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          '$_seconds s',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: _recording ? Colors.red : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasVoice)
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton.icon(
              onPressed: _busy ? null : _toggleRecord,
              style: FilledButton.styleFrom(
                backgroundColor: _recording
                    ? Colors.red.shade700
                    : Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? 'STOP RECORDING' : 'RECORD VOICE'),
            ),
          ),
        if (hasVoice) ...[
          // The mandatory explanation is recorded: confirm closes the dispute.
          _verdictButton(
            label: 'CONFIRM ISSUE',
            icon: Icons.report_problem,
            color: Colors.red.shade700,
            enabled: !_busy,
            onTap: () => _finish(false),
          ),
          TextButton(
            onPressed: _busy || _recording ? null : _toggleRecord,
            child: const Text('Re-record the voice note'),
          ),
        ],
        TextButton(
          onPressed: _busy || _recording ? null : _backToPhoto,
          child: const Text('Back'),
        ),
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel reception'),
        ),
      ],
    );
  }

  /// Back from the issue branch: drop any recorded voice (a stale note must
  /// never leak into a later ACCEPT ALL) and return to the verdict.
  void _backToPhoto() {
    final stale = _voicePath;
    setState(() {
      _step = 0;
      _voicePath = '';
      _seconds = 0;
    });
    if (stale.isNotEmpty) unawaited(_deleteQuietly(stale));
  }

  /// One giant verdict: an icon of size 28 with its caption underneath, on the
  /// verdict's own solid colour (same contract as the sheet's action bar).
  /// [enabled] false dims it and blocks the tap (verdicts before the
  /// auto-camera produced a photo; CONFIRM before the voice is recorded).
  Widget _verdictButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: double.infinity,
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
