import re

with open(r'C:\Users\Lenovo\Desktop\sigat\hydra_v0\lib\screens\report_detail_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = '''  }
}

/// Modal sheet used by the rejection flow to capture the mandatory spoken
/// explanation. Starts recording immediately, auto-stops after 15 seconds
/// (like the report voice note) and pops the persisted file path — or null
/// when the TL cancels or the recording never finalized on disk.
class _RejectionVoiceRecorder extends StatefulWidget {'''

new = '''  }
}

// ---------------------------------------------------------------------------
// Resubmit capture sheet: photo + optional voice note.
// ---------------------------------------------------------------------------
class _ResubmitCaptureSheet extends StatefulWidget {
  const _ResubmitCaptureSheet();

  @override
  State<_ResubmitCaptureSheet> createState() => _ResubmitCaptureSheetState();
}

class _ResubmitCaptureSheetState extends State<_ResubmitCaptureSheet> {
  final ImagePicker _picker = ImagePicker();
  String? _photoPath;
  String? _voicePath;
  bool _saving = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _ticker;
  Timer? _autoStop;
  late final AudioRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoStop?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = await Directory('${dir.path}/reports').create(recursive: true);
    final savedPath = '${reportsDir.path}/resubmit_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      photo.path,
      savedPath,
      minWidth: 640,
      minHeight: 640,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    final finalPath = compressed?.path ?? photo.path;
    setState(() => _photoPath = finalPath);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    try {
      if (!await _recorder.hasPermission()) return;
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory('${dir.path}/reports').create(recursive: true);
      final path = '${reportsDir.path}/resubmit_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _recordSeconds++));
      _autoStop = Timer(const Duration(seconds: 15), _stopRecording);
    } catch (e) {
      debugPrint('ResubmitFlow: recording failed: $e');
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _autoStop?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    try {
      final path = await _recorder.stop();
      if (path != null && await File(path).exists() && (await File(path).length()) > 0) {
        setState(() => _voicePath = path);
      }
    } catch (e) {
      debugPrint('ResubmitFlow: stop recording failed: $e');
    }
  }

  Future<void> _submit() async {
    if (_photoPath == null || _photoPath!.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);
    await _stopRecording();
    if (!mounted) return;
    Navigator.of(context).pop((
      photoPath: _photoPath!,
      voicePath: _voicePath ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _photoPath == null ? 'Take new photo' : 'Retake photo',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photoPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _takePhoto,
                icon: Icon(_photoPath == null ? Icons.camera_alt : Icons.refresh),
                label: Text(_photoPath == null ? 'CAPTURE PHOTO' : 'RETAKE PHOTO'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _voicePath == null ? 'Add voice note (optional)' : 'Voice captured',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _recording ? '$_recordSeconds s' : '$_recordSeconds s',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: _recording ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _toggleRecord,
                style: FilledButton.styleFrom(
                  backgroundColor: _recording ? Colors.red.shade700 : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(_recording ? 'STOP RECORDING' : 'RECORD VOICE'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _saving || _photoPath == null ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet used by the rejection flow to capture the mandatory spoken
/// explanation. Starts recording immediately, auto-stops after 15 seconds
/// (like the report voice note) and pops the persisted file path — or null
/// when the TL cancels or the recording never finalized on disk.
class _RejectionVoiceRecorder extends StatefulWidget {'''

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Lenovo\Desktop\sigat\hydra_v0\lib\screens\report_detail_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Replacement successful')
else:
    print('Old string not found')
