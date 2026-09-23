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
//   Step 1 (photo): the camera, a thumbnail of what was captured, then 'Next'.
//   Step 2 (voice): the microphone, then the two giant verdicts
//                   [ACCEPT ALL] (green) / [REPORT ISSUE] (red).
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

/// Opens the two-step reception capture sheet. Returns null when the user
/// cancels, in which case the report is left untouched.
Future<MaterialReceptionResult?> showMaterialReceptionSheet(
  BuildContext context,
) {
  return showModalBottomSheet<MaterialReceptionResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const MaterialReceptionSheet(),
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
  const MaterialReceptionSheet({super.key});

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

  /// 0 = delivery photo, 1 = voice note + verdict.
  int _step = 0;
  String _photoPath = '';
  String _voicePath = '';
  bool _recording = false;
  int _seconds = 0;
  bool _busy = false;
  Timer? _ticker;
  Timer? _autoStop;

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

  /// Step 1: camera → compressed persistent JPEG (light enough for a slow
  /// link), shown as the thumbnail the user confirms before moving on.
  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
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
      final finalPath = compressed?.path ?? photo.path;
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

  /// Closes the sheet with the binary verdict: ACCEPT ALL (accepted) or REPORT
  /// ISSUE (the delivery dispute).
  Future<void> _finish(bool accepted) async {
    if (_busy || _photoPath.isEmpty || _voicePath.isEmpty) return;
    setState(() => _busy = true);
    await _stopRecording();
    if (!mounted) return;
    Navigator.of(context).pop((
      photoPath: _photoPath,
      voicePath: _voicePath,
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

  /// Step 1/2 — the delivery photo, then 'Next'.
  Widget _photoStep() {
    final hasPhoto = _photoPath.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'STEP 1/2 — DELIVERY PHOTO',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Photograph what arrived: the material, the quantity, any damage.',
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
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy ? null : _takePhoto,
            icon: Icon(hasPhoto ? Icons.refresh : Icons.camera_alt),
            label: Text(hasPhoto ? 'RETAKE PHOTO' : 'TAKE PHOTO'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: hasPhoto && !_busy
                ? () => setState(() => _step = 1)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'NEXT: RECORD VOICE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel reception'),
        ),
      ],
    );
  }

  /// Step 2/2 — the voice note, then the two giant verdicts.
  Widget _voiceStep() {
    final hasVoice = _voicePath.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'STEP 2/2 — VOICE NOTE',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          hasVoice
              ? 'Voice captured — give the verdict now.'
              : 'Say what arrived, and what is missing or broken.',
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
          // The binary decision: everything arrived, or there is a dispute.
          Row(
            children: [
              Expanded(
                child: _verdictButton(
                  label: 'ACCEPT ALL',
                  icon: Icons.check_circle,
                  color: Colors.green.shade700,
                  onTap: () => _finish(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _verdictButton(
                  label: 'REPORT ISSUE',
                  icon: Icons.report_problem,
                  color: Colors.red.shade700,
                  onTap: () => _finish(false),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _busy || _recording ? null : _toggleRecord,
            child: const Text('Re-record the voice note'),
          ),
        ],
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('Cancel reception'),
        ),
      ],
    );
  }

  /// One giant verdict: an icon of size 28 with its caption underneath, on the
  /// verdict's own solid colour (same contract as the sheet's action bar).
  Widget _verdictButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : onTap,
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
    );
  }
}
