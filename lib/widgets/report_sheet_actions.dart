import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/report.dart';
import '../role.dart';
import '../screens/owner_action_sheet.dart' show OwnerDecisionWriter;
import '../services/database_service.dart';
import '../services/report_local_service.dart';
import '../services/sync_service.dart';
import 'material_reception_sheet.dart';
import 'notify_gate.dart';
import 'report_detail_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// The one place the Team Leader gate and the subcontractor's "Fix & Resubmit"
// flows live. Both used to be private methods of `ReportDetailScreen`, which
// made the flows impossible to reach from anywhere else (the map and the
// history had to push a whole screen just to reuse three buttons).
//
// Every flow here takes (context, report) and returns true when the report was
// changed and the caller may close its surface (the sheet pops itself, the
// legacy detail screen pops its route). Offline-first is preserved: the local
// write always happens, the cloud push is fired and forgotten.
// ---------------------------------------------------------------------------

/// Radius (in metres) within which an on-site Team Leader validation counts as
/// 'physical' — i.e. the TL really was standing on the report's spot. Beyond it
/// (or when the distance is unknown) the decision is downgraded to 'remote'.
const double tlPhysicalRadiusMeters = 50;

/// Classifies an on-site validation from the measured distance between the
/// report and the Team Leader.
///
/// Returns 'physical' only when [meters] is a known distance inside
/// [tlPhysicalRadiusMeters]; otherwise 'remote'. A negative [meters] means the
/// distance could not be measured (e.g. the report has no captured GPS), which
/// must never be recorded as a physical proof.
String tlValidationTypeForDistance(double meters) =>
    meters >= 0 && meters < tlPhysicalRadiusMeters ? 'physical' : 'remote';

/// The Team Leader account recorded on a validation decision. The app uses a
/// single local account convention (`tl_1`), reusing the report's own user id.
String tlValidatorIdOf(Report report) =>
    report.userId.isNotEmpty ? report.userId : 'tl_1';

/// 'VALIDATE REMOTELY (Photo Only)': no proof photo and no GPS check — the TL
/// simply confirms the report from wherever they are.
Future<bool> tlValidateRemotelyFlow(BuildContext context, Report report) async {
  try {
    report.tlValidatorId = tlValidatorIdOf(report);
    report.tlValidationType = 'remote';
    // Remote validation carries no proof photo; clear any previous one so the
    // remote row cannot keep a stale photo from an earlier on-site attempt.
    report.tlValidationPhotoPath = '';
    report.tlValidationPhotoUrl = '';
    await DatabaseService.markTlValidated(report);
    debugPrint('TlGate: report ${report.id} validated remotely');
    if (!context.mounted) return true;
    notifyGate(context, 'Validated remotely');
    // Offline-first: no-ops offline and is retried on the next sync trigger.
    unawaited(SyncService.syncPendingReports());
    return true;
  } catch (e, st) {
    debugPrint('TlGate: remote validation failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(context, 'Validation failed');
    return false;
  }
}

/// 'VALIDATE ON SITE (Take Photo)': captures a proof photo, then compares the
/// TL's current GPS position with the report's location. Within
/// [tlPhysicalRadiusMeters] the decision is 'physical'; further away (or
/// unknown) it is downgraded to 'remote' because the TL wasn't on the spot.
Future<bool> tlValidateOnSiteFlow(BuildContext context, Report report) async {
  try {
    final XFile? photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (photo == null) {
      // Camera cancelled: leave the report untouched in the TO VERIFY tab.
      debugPrint('TlGate: on-site validation cancelled by the user');
      return false;
    }

    final proofPath = await persistCapture(photo.path);
    if (proofPath.isEmpty) {
      if (!context.mounted) return false;
      notifyGate(context, 'Photo capture failed');
      return false;
    }

    final position = await acquireTlPosition();
    var validationType = 'remote';
    var distanceLabel = 'location unavailable';
    if (position != null) {
      // Great-circle distance between the report and the TL right now.
      final meters = Geolocator.distanceBetween(
        report.lat,
        report.lng,
        position.latitude,
        position.longitude,
      );
      validationType = tlValidationTypeForDistance(meters);
      distanceLabel = '${meters.round()} m away';
      debugPrint(
        'TlGate: report ${report.id} is $distanceLabel -> $validationType',
      );
    } else {
      debugPrint('TlGate: no TL position — recording a remote validation');
    }

    report.tlValidatorId = tlValidatorIdOf(report);
    report.tlValidationType = validationType;
    report.tlValidationPhotoPath = proofPath;
    // A re-validation replaces any previously uploaded proof photo.
    report.tlValidationPhotoUrl = '';
    await DatabaseService.markTlValidated(report);
    if (!context.mounted) return true;
    notifyGate(
      context,
      validationType == 'physical'
          ? 'Validated on site ($distanceLabel)'
          : 'Validated remotely ($distanceLabel)',
    );
    unawaited(SyncService.syncPendingReports());
    return true;
  } catch (e, st) {
    debugPrint('TlGate: on-site validation failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(context, 'Validation failed');
    return false;
  }
}

/// 'REJECT (Photo + Voice)': the "Dispute Shield". Both a proof photo and a
/// spoken explanation are mandatory so the rejection stays defensible later.
/// Cancelling at any step leaves the report untouched in the TO VERIFY tab.
Future<bool> tlRejectFlow(BuildContext context, Report report) async {
  try {
    final XFile? photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (photo == null) {
      debugPrint('TlGate: rejection cancelled at the camera step');
      return false;
    }
    final proofPath = await persistCapture(photo.path);
    if (proofPath.isEmpty) {
      if (!context.mounted) return false;
      notifyGate(context, 'Photo capture failed');
      return false;
    }

    if (!context.mounted) return false;
    final voicePath = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RejectionVoiceRecorder(),
    );
    if (voicePath == null || voicePath.isEmpty) {
      // No voice note means no defensible rejection: drop the photo and
      // leave the report in the TO VERIFY tab.
      debugPrint('TlGate: rejection cancelled at the voice step');
      try {
        await File(proofPath).delete();
      } catch (e, st) {
        debugPrint('TlGate: rejected proof cleanup failed: $e\n$st');
      }
      if (!context.mounted) return false;
      notifyGate(context, 'Voice note required to reject');
      return false;
    }

    report.addTimelineEvent(
      actor: 'tl',
      action: 'reject',
      photoPath: proofPath,
      voicePath: voicePath,
    );
    report.tlValidatorId = tlValidatorIdOf(report);
    report.tlValidationType = 'rejected';
    // A rejection has its own proof media; clear the on-site validation
    // photo so a stale one can never be mistaken for this decision's proof.
    report.tlValidationPhotoPath = '';
    report.tlValidationPhotoUrl = '';
    // A re-rejection replaces any previously captured proof media.
    report.tlRejectionPhotoPath = proofPath;
    report.tlRejectionPhotoUrl = '';
    report.tlRejectionVoicePath = voicePath;
    report.tlRejectionVoiceUrl = '';
    await DatabaseService.markTlValidated(report);
    debugPrint('TlGate: report ${report.id} rejected (photo + voice)');
    if (!context.mounted) return true;
    notifyGate(context, 'Report rejected');
    unawaited(SyncService.syncPendingReports());
    return true;
  } catch (e, st) {
    debugPrint('TlGate: rejection failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(context, 'Rejection failed');
    return false;
  }
}

/// The subcontractor's "FIX & RESUBMIT": a new proof photo (+ optional voice
/// note) is captured, the report re-queues for sync and returns to the TL's
/// inbox with a clean gate. The old media moves into the thread (the resubmit
/// bubble keeps the before-picture) and the old decision is voided.
Future<bool> subFixAndResubmitFlow(BuildContext context, Report report) async {
  try {
    if (!context.mounted) return false;
    final captured =
        await showModalBottomSheet<({String photoPath, String? voicePath})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const ResubmitCaptureSheet(),
        );
    if (captured == null || captured.photoPath.isEmpty) {
      debugPrint('ResubmitFlow: cancelled by the user');
      return false;
    }

    final oldPhotoPath = report.photoPath;
    final oldVoicePath = report.voicePath;
    // The before-picture (and voice note) move into the thread. Both the local
    // file AND the cloud copy are carried over: after the 7-day "Hybrid Shield"
    // cleanup the file is gone while the URL is still valid, and dropping it
    // here is what used to make the original evidence unrecoverable once the
    // resubmit replaced the report's own photo.
    report.addTimelineEvent(
      actor: 'sub',
      action: 'resubmit',
      photoPath: oldPhotoPath,
      photoUrl: report.photoUrl,
      voicePath: oldVoicePath,
      voiceUrl: report.voiceUrl,
    );
    report
      ..photoPath = captured.photoPath
      ..voicePath = captured.voicePath ?? ''
      ..photoUrl =
          '' // force a fresh upload of the new capture
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
    await DatabaseService.saveSubStatus(report);
    debugPrint('ResubmitFlow: report ${report.id} resubmitted for review');
    if (!context.mounted) return true;
    notifyGate(context, 'Submitted for re-verification');
    // Offline-first: the new photo + cleared gate are pushed when online.
    unawaited(SyncService.syncPendingReports());
    return true;
  } catch (e, st) {
    debugPrint('ResubmitFlow: failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(context, 'Resubmission failed');
    return false;
  }
}

/// The Team Leader gate as sheet actions: the three-way decision, written out.
///
/// Three giant direct buttons — every one runs its flow on a single tap:
///   - REMOTE   → the decision is written immediately, no photo;
///   - ON SITE  → the camera captures the GPS proof (the distance decides
///     whether the record is 'physical' or downgraded to 'remote');
///   - REJECT   → the "Dispute Shield": the camera plus the mandatory voice
///     explanation, appended to the thread as the TL's right-aligned red
///     bubble.
ReportSheetActions tlGateActions() => ReportSheetActions(
  buttons: [
    ReportSheetAction(
      label: 'REMOTE',
      color: Colors.green,
      icon: Icons.visibility,
      onPressed: tlValidateRemotelyFlow,
    ),
    ReportSheetAction(
      label: 'ON SITE',
      color: Colors.green,
      icon: Icons.camera_alt,
      onPressed: tlValidateOnSiteFlow,
    ),
    ReportSheetAction(
      label: 'REJECT',
      color: Colors.red,
      icon: Icons.close,
      onPressed: tlRejectFlow,
    ),
  ],
);

/// Returns true when the subcontractor owes a fix on this report: the Team
/// Leader rejected it, or the Owner rejected it (a rejection never locks the
/// conversation — the sub must still be able to argue or fix).
///
/// A "Material Reception" delivery dispute is deliberately excluded: that
/// rejection is about what the supplier delivered, not about the sub's work, so
/// asking him to "fix and resubmit" would be meaningless (and would push the
/// report back through the Team Leader gate while the Owner is handling the
/// dispute). The report stays with the Owner.
bool subOwesAFix(Report report) =>
    report.isTlRejected ||
    (report.ownerStatus == 'rejected' && !report.hasDeliveryDispute);

/// The subcontractor's single "FIX & RESUBMIT" action, shown when the Team
/// Leader rejected the report (the red stage): one giant green camera button
/// that opens the photo + voice capture flow.
ReportSheetActions subFixActions() => ReportSheetActions(
  note: 'Rejected by the Team Leader — fix it, then resubmit with a new photo.',
  buttons: [
    ReportSheetAction(
      label: 'FIX & RESUBMIT',
      color: Colors.green,
      icon: Icons.camera_alt,
      onPressed: subFixAndResubmitFlow,
    ),
  ],
);

// ---------------------------------------------------------------------------
// "Material Reception": the ordered material is delivered on site.
//
// The Owner ordered it (owner_status 'ordered'), so the report is closed at the
// owner layer — yet the field team still has one binary job: receive the
// delivery with a photo plus a voice note, and either ACCEPT ALL ('validated')
// or REPORT ISSUE ('rejected', the red delivery dispute the Owner sees).
//
// The two field roles do it; the Owner, who placed the order, never does.
// ---------------------------------------------------------------------------

/// True when [report] is an ordered material nobody has received yet **and**
/// [role] may receive it (anybody but the Owner).
bool materialReceptionNeeded(Report report, String role) =>
    report.awaitsMaterialReception && role != 'owner';

/// The single giant action of an ordered material awaiting its delivery: one
/// blue button, filling the whole bar. The flow itself lives next to the
/// capture sheet (`material_reception_sheet.dart`) so the detail sheet can run
/// it too without an import cycle.
ReportSheetActions materialReceptionActions() => ReportSheetActions(
  note: 'The Owner ordered this material — receive it with a photo and a '
      'voice note.',
  buttons: [
    ReportSheetAction(
      label: 'RECEIVE MATERIAL',
      color: Colors.blue,
      icon: Icons.inventory_2,
      onPressed: materialReceptionFlow,
    ),
  ],
);

/// The default action set for [report] given who is looking at it. One source
/// of truth shared by the History list, the map, the Team Leader dashboard and
/// the legacy full-screen host, so the same report always shows the same
/// buttons wherever it is opened.
///
/// - An ordered material the field team has not received yet: the giant
///   'RECEIVE MATERIAL' action (both field roles, never the Owner).
/// - A closed report (the Owner decided): no actions — the sheet shows its
///   disabled grey 'WORK CLOSED' bar.
/// - A Team Leader and a report still awaiting the gate: REMOTE / ON SITE / REJECT.
/// - A subcontractor looking at a rejected report: FIX & RESUBMIT.
/// - Anything else: nothing to do, so no bar at all.
ReportSheetActions defaultActionsFor(Report report, {String? role}) {
  final effectiveRole = role ?? userRole;
  // "Material Reception" comes first: an ordered material is 'closed' at the
  // owner layer, yet it is exactly the state that still owes the delivery
  // decision — the closed bar must not swallow it.
  if (materialReceptionNeeded(report, effectiveRole)) {
    return materialReceptionActions();
  }
  if (isReportClosedByOwner(report)) return const ReportSheetActions();
  if (effectiveRole == 'team_leader') {
    // `needsTlValidation` is (work|material) && tlValidatedAt == null: the
    // "TL && tlValidatedAt == null" rule plus the domain guard that keeps
    // 'problem' reports — which never pass the gate — out of the TL's queue.
    return report.needsTlValidation
        ? tlGateActions()
        : const ReportSheetActions();
  }
  return subOwesAFix(report) ? subFixActions() : const ReportSheetActions();
}

// ---------------------------------------------------------------------------
// The Owner's giant actions for the report sheet.
//
// The Owner is a thin client over Supabase: his decisions go straight to the
// `reports.owner_status` column through the same [OwnerDecisionWriter] seam the
// map's decision sheet already uses (defined in `owner_action_sheet.dart`,
// injected in tests). A REJECTION keeps the bar alive — the owner can change
// his mind, and the field team keeps its FIX & RESUBMIT.
// ---------------------------------------------------------------------------

/// One owner decision: writes [status] to the cloud row keyed by the report's
/// local id (carried in `report.userId` by the owner's row mapper).
ReportActionCallback ownerDecideFlow(
  String status,
  OwnerDecisionWriter write,
) => (BuildContext context, Report report) async {
  try {
    await write(report.userId, status);
    if (!context.mounted) return true;
    notifyGate(context, 'Decision saved');
    return true;
  } catch (e, st) {
    debugPrint('OwnerFlow: decision "$status" failed: $e\n$st');
    if (!context.mounted) return false;
    notifyGate(
      context,
      'Decision not saved — connect and try again.',
    );
    return false;
  }
};

/// The owner's action bar for one report: the type-specific primary decision
/// plus REJECT, both live while the report is not finally decided (a
/// rejection keeps the bar — see [subOwesAFix]).
ReportSheetActions ownerReportActions({
  required Report report,
  required OwnerDecisionWriter writeDecision,
}) {
  final type = report.type;
  final primary = switch (type) {
    'problem' => (
      'ACKNOWLEDGE',
      'acknowledged',
      Colors.blue,
      Icons.visibility,
    ),
    'material' => (
      'ORDER',
      'ordered',
      Colors.orange,
      Icons.local_shipping,
    ),
    _ => ('VALIDATE', 'validated', Colors.green, Icons.check_circle),
  };
  return ReportSheetActions(
    buttons: [
      ReportSheetAction(
        label: primary.$1,
        color: primary.$3,
        icon: primary.$4,
        onPressed: ownerDecideFlow(primary.$2, writeDecision),
      ),
      ReportSheetAction(
        label: 'REJECT',
        color: Colors.red,
        icon: Icons.close,
        onPressed: ownerDecideFlow('rejected', writeDecision),
      ),
    ],
  );
}

/// One-liner for surfaces (list tile, map pin, dashboard): resolves the
/// default actions for [report] and opens the shared report sheet.
/// [role] overrides the compile-time role (tests); [selfActor] overrides the
/// actor that labels the bubbles a capture flow adds.
Future<bool?> showDefaultReportDetailSheet(
  BuildContext context,
  Report report, {
  String? role,
  String? selfActor,
}) => showReportDetailSheet(
  context,
  report: report,
  actions: defaultActionsFor(report, role: role),
  selfActor: selfActor,
);

/// Compresses a raw camera capture into a small persistent JPEG inside
/// `<documents>/reports` and returns its absolute path ('' on failure).
/// Mirrors the Home screen capture flow so uploads stay light on slow links.
///
/// [prefix] names the file, so every flow keeps its own captures apart
/// ('verify' for the Team Leader proof, 'reception' for a material delivery)
/// while uploading through the same helper.
Future<String> persistCapture(String rawPath, {String prefix = 'verify'}) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = await Directory(
      '${dir.path}/reports',
    ).create(recursive: true);
    final savedPath =
        '${reportsDir.path}/${prefix}_'
        '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      rawPath,
      savedPath,
      minWidth: 640,
      minHeight: 640,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (compressed != null) {
      // The raw capture is no longer needed; drop it to save space.
      try {
        await File(rawPath).delete();
      } catch (e, st) {
        debugPrint('CaptureFlow: raw capture cleanup failed: $e\n$st');
      }
      debugPrint('CaptureFlow: photo stored at ${compressed.path}');
      return compressed.path;
    }
    // Compression failed — keep the original capture if it is usable.
    if (await ReportLocalService.isValidFile(rawPath)) return rawPath;
    return '';
  } catch (e, st) {
    debugPrint('CaptureFlow: persistCapture failed: $e\n$st');
    return '';
  }
}

/// The TL's current position, or null when location services/permission are
/// unavailable. Same guarded lookup used by the report save flow, so a denied
/// permission degrades to a 'remote' validation instead of blocking the TL.
Future<Position?> acquireTlPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('TlGate: location services disabled');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('TlGate: location permission=$permission');
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    debugPrint('TlGate: TL position lat=${pos.latitude} lng=${pos.longitude}');
    return pos;
  } catch (e, st) {
    debugPrint('TlGate: TL position failed: $e\n$st');
    return null;
  }
}

/// Bottom sheet that lets the subcontractor capture a new proof photo and
/// record an optional voice note before resubmitting. Returns the captured
/// media paths, or null if the user cancels.
class ResubmitCaptureSheet extends StatefulWidget {
  const ResubmitCaptureSheet({super.key});

  @override
  State<ResubmitCaptureSheet> createState() => _ResubmitCaptureSheetState();
}

class _ResubmitCaptureSheetState extends State<ResubmitCaptureSheet> {
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
    final reportsDir = await Directory(
      '${dir.path}/reports',
    ).create(recursive: true);
    final savedPath =
        '${reportsDir.path}/resubmit_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final path =
          '${reportsDir.path}/resubmit_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _recordSeconds++),
      );
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
      if (path != null &&
          await File(path).exists() &&
          (await File(path).length()) > 0) {
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
    Navigator.of(
      context,
    ).pop((photoPath: _photoPath!, voicePath: _voicePath ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                icon: Icon(
                  _photoPath == null ? Icons.camera_alt : Icons.refresh,
                ),
                label: Text(
                  _photoPath == null ? 'CAPTURE PHOTO' : 'RETAKE PHOTO',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _voicePath == null
                  ? 'Add voice note (optional)'
                  : 'Voice captured',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$_recordSeconds s',
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
                  backgroundColor: _recording
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
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
                    : const Text(
                        'SUBMIT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

/// Modal sheet used by the rejection flow to capture the mandatory spoken
/// explanation. Starts recording immediately, auto-stops after 15 seconds
/// (like the report voice note) and pops the persisted file path — or null
/// when the TL cancels or the recording never finalized on disk.
class RejectionVoiceRecorder extends StatefulWidget {
  const RejectionVoiceRecorder({super.key});

  @override
  State<RejectionVoiceRecorder> createState() => _RejectionVoiceRecorderState();
}

class _RejectionVoiceRecorderState extends State<RejectionVoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  Timer? _autoStop;
  int _seconds = 0;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoStop?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        debugPrint('RejectFlow: microphone permission denied');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final path =
          '${reportsDir.path}/reject_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {});
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _seconds++),
      );
      _autoStop = Timer(const Duration(seconds: 15), _stop);
    } catch (e, st) {
      debugPrint('RejectFlow: voice recording failed: $e\n$st');
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Stops, waits for the muxer to flush a non-empty file (same probe as the
  /// save flow) and pops the path. A null result means the recording is not
  /// usable and the TL must retry or cancel the rejection.
  Future<void> _stop() async {
    if (_settling) return;
    _settling = true;
    _ticker?.cancel();
    _autoStop?.cancel();
    try {
      final path = await _recorder.stop();
      var valid = false;
      if (path != null) {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          try {
            final f = File(path);
            if (f.existsSync() && f.lengthSync() > 0) {
              valid = true;
              break;
            }
          } catch (e, st) {
            debugPrint('RejectFlow: voice file probe failed: $e\n$st');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      if (mounted) Navigator.of(context).pop(valid ? path : null);
    } catch (e, st) {
      debugPrint('RejectFlow: voice stop failed: $e\n$st');
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Aborts the capture: stops the recorder, deletes the partial file and pops
  /// null so the caller abandons the whole rejection.
  Future<void> _cancel() async {
    if (_settling) return;
    _settling = true;
    _ticker?.cancel();
    _autoStop?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('RejectFlow: voice cancel failed: $e\n$st');
    }
    if (mounted) Navigator.of(context).pop();
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Explain the rejection (max 15s)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$_seconds s',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: _seconds > 0 ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _seconds > 0 ? _stop : null,
                icon: const Icon(Icons.stop),
                label: const Text(
                  'STOP & SAVE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cancel,
              child: const Text('Cancel rejection'),
            ),
          ],
        ),
      ),
    );
  }
}
