import re

with open(r'C:\Users\Lenovo\Desktop\sigat\hydra_v0\lib\screens\report_detail_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = '''  // ---------------------------------------------------------------------------
  // "Fix & Resubmit" loop: the subcontractor answers a rejection.
  // ---------------------------------------------------------------------------

  /// Giant green button: the subcontractor re-captures the proof photo, the
  /// report re-queues for sync and returns to the TL's inbox with a clean gate.
  Future<void> _fixAndResubmit() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        // Camera cancelled: leave the report rejected and untouched.
        debugPrint('ResubmitFlow: cancelled by the user');
        if (mounted) setState(() => _validating = false);
        return;
      }
      final newPath = await _persistCapture(photo.path);
      if (newPath.isEmpty) {
        _failValidation('Photo capture failed');
        return;
      }

      final oldPhotoPath = _report.photoPath;
      final oldVoicePath = _report.voicePath;
      _report.addTimelineEvent(
        actor: 'sub',
        action: 'resubmit',
        photoUrl: oldPhotoPath,
        voiceUrl: oldVoicePath,
      );
      _report
        ..photoPath = newPath
        ..photoUrl = '' // force a fresh upload of the new capture
        ..photoStatus = 'pending'
        ..status = 'local'
        ..dbStatus = 'pending'
        // The old decision is void: the report re-enters the TL's queue.
        ..tlValidatedAt = null
        ..tlValidationType = ''
        ..tlValidationPhotoPath = ''
        ..tlValidationPhotoUrl = ''
        // Keep tlRejectionPhotoPath/Url + the log: the dispute history stays.
        ..logActivity(actor: 'sub', action: 'resubmitted');
      await DatabaseService.saveSubStatus(_report);
      debugPrint('ResubmitFlow: report ${_report.id} resubmitted for review');
      if (mounted) {
        setState(() {}); // refresh: green bar disappears, pending chip shows
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for re-verification')),
        );
      }
      // Offline-first: the new photo + cleared gate are pushed when online.
      unawaited(SyncService.syncPendingReports());
    } catch (e, st) {
      debugPrint('ResubmitFlow: failed: $e\\\\n$st');
      _failValidation('Resubmission failed');
    }
  }'''

new = '''  // ---------------------------------------------------------------------------
  // "Fix & Resubmit" capture sheet: photo + optional voice note.
  // ---------------------------------------------------------------------------

  /// Bottom sheet that lets the subcontractor capture a new proof photo and
  /// record an optional voice note before resubmitting. Returns the captured
  /// media paths, or null if the user cancels.
  Future<({String photoPath, String? voicePath})?> _showResubmitSheet() async {
    if (!mounted) return null;
    return await showModalBottomSheet<({String photoPath, String? voicePath})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ResubmitCaptureSheet(),
    );
  }

  /// Giant green button: the subcontractor re-captures the proof photo, the
  /// report re-queues for sync and returns to the TL's inbox with a clean gate.
  Future<void> _fixAndResubmit() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final captured = await _showResubmitSheet();
      if (captured == null || captured.photoPath.isEmpty) {
        debugPrint('ResubmitFlow: cancelled by the user');
        if (mounted) setState(() => _validating = false);
        return;
      }

      final newPhotoPath = captured.photoPath;
      final newVoicePath = captured.voicePath ?? '';

      final oldPhotoPath = _report.photoPath;
      final oldVoicePath = _report.voicePath;
      _report.addTimelineEvent(
        actor: 'sub',
        action: 'resubmit',
        photoUrl: oldPhotoPath,
        voiceUrl: oldVoicePath,
      );
      _report
        ..photoPath = newPhotoPath
        ..voicePath = newVoicePath
        ..photoUrl = '' // force a fresh upload of the new capture
        ..voiceUrl = ''
        ..photoStatus = 'pending'
        ..voiceStatus = 'pending'
        ..status = 'local'
        ..dbStatus = 'pending'
        // The old decision is void: the report re-enters the TL's queue.
        ..tlValidatedAt = null
        ..tlValidationType = ''
        ..tlValidationPhotoPath = ''
        ..tlValidationPhotoUrl = ''
        // Keep tlRejectionPhotoPath/Url + the log: the dispute history stays.
        ..logActivity(actor: 'sub', action: 'resubmitted');
      await DatabaseService.saveSubStatus(_report);
      debugPrint('ResubmitFlow: report ${_report.id} resubmitted for review');
      if (mounted) {
        setState(() {}); // refresh: green bar disappears, pending chip shows
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for re-verification')),
        );
      }
      // Offline-first: the new photo + cleared gate are pushed when online.
      unawaited(SyncService.syncPendingReports());
    } catch (e, st) {
      debugPrint('ResubmitFlow: failed: $e\\n$st');
      _failValidation('Resubmission failed');
    }
  }'''

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Lenovo\Desktop\sigat\hydra_v0\lib\screens\report_detail_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Replacement successful')
else:
    print('Old string not found')
