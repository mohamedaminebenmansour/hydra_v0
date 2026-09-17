import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/report.dart';
import '../services/database_service.dart';
import '../services/report_local_service.dart';
import '../services/sync_service.dart';
import '../widgets/back_button_circle.dart';
import '../widgets/timeline_audio_player.dart';

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

/// Shows a single Report with the photo and a play button for its voice note.
///
/// When opened from the History 'TO VERIFY' tab ([validationMode] is true) it
/// also hosts the "Chef de Chantier Gate": three giant Team Leader decision
/// buttons (validate remotely, validate on site, reject) at the bottom.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    this.validationMode = false,
    this.userRoleOverride,
  });

  final Report report;

  /// True when the screen is showing the Team Leader verification step, so the
  /// remote / on-site / reject actions are offered.
  final bool validationMode;

  /// Test seam for the compile-time role. Null falls back to the
  /// [userRole] dart-define; tests pass 'team_leader' or 'subcontractor' to
  /// exercise both roles in one plain `flutter test` run.
  final String? userRoleOverride;

  /// True when the signed-in user is a Team Leader. The "Chef de Chantier
  /// Gate" buttons are exclusive to that role — a subcontractor opening their
  /// own report can never validate or reject it, whatever [validationMode] is.
  bool get isTeamLeader =>
      (userRoleOverride ??
          const String.fromEnvironment(
            'USER_ROLE',
            defaultValue: 'subcontractor',
          )) ==
      'team_leader';

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with WidgetsBindingObserver {
  /// Latest copy of the report, refreshed from Isar on focus changes.
  late Report _report;
  late Future<Report?> _reportFuture;

  /// Camera access for the 'VALIDATE ON SITE' proof photo.
  final ImagePicker _picker = ImagePicker();

  /// True while a Team Leader validation is in flight. Disables both gate
  /// buttons so a double tap can never validate the same report twice.
  bool _validating = false;

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

  /// Opens the report's GPS coordinates in the external maps launcher.
  Future<void> _openInMaps() async {
    final lat = _report.lat;
    final lng = _report.lng;
    if (lat == 0 && lng == 0) return;
    try {
      await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      debugPrint('MapFlow: open failed: $e\n$st');
    }
  }

// ---------------------------------------------------------------------------
  // "Chef de Chantier Gate": Team Leader validation.
  // ---------------------------------------------------------------------------

  /// The Team Leader account recorded on a validation decision. The app uses a
  /// single local account convention (`tl_1`), reusing the report's own user id.
  String get _tlValidatorId =>
      _report.userId.isNotEmpty ? _report.userId : 'tl_1';

  /// 'VALIDATE REMOTELY (Photo Only)': no proof photo and no GPS check — the TL
  /// simply confirms the report from wherever they are.
  Future<void> _validateRemotely() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      _report.tlValidatorId = _tlValidatorId;
      _report.tlValidationType = 'remote';
      // Remote validation carries no proof photo; clear any previous one so the
      // remote row cannot keep a stale photo from an earlier on-site attempt.
      _report.tlValidationPhotoPath = '';
      _report.tlValidationPhotoUrl = '';
      await DatabaseService.markTlValidated(_report);
      debugPrint('TlGate: report ${_report.id} validated remotely');
      _finishValidation('Validated remotely');
    } catch (e, st) {
      debugPrint('TlGate: remote validation failed: $e\n$st');
      _failValidation('Validation failed');
    }
  }

  /// 'VALIDATE ON SITE (Take Photo)': captures a proof photo, then compares the
  /// TL's current GPS position with the report's location. Within
  /// [tlPhysicalRadiusMeters] the decision is 'physical'; further away (or
  /// unknown) it is downgraded to 'remote' because the TL wasn't on the spot.
  Future<void> _validateOnSite() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        // Camera cancelled: leave the report untouched in the TO VERIFY tab.
        debugPrint('TlGate: on-site validation cancelled by the user');
        if (mounted) setState(() => _validating = false);
        return;
      }

      final proofPath = await _persistCapture(photo.path);
      if (proofPath.isEmpty) {
        _failValidation('Photo capture failed');
        return;
      }

      final position = await _acquireTlPosition();
      var validationType = 'remote';
      var distanceLabel = 'location unavailable';
      if (position != null) {
        // Great-circle distance between the report and the TL right now.
        final meters = Geolocator.distanceBetween(
          _report.lat,
          _report.lng,
          position.latitude,
          position.longitude,
        );
        validationType = tlValidationTypeForDistance(meters);
        distanceLabel = '${meters.round()} m away';
        debugPrint(
          'TlGate: report ${_report.id} is $distanceLabel -> $validationType',
        );
      } else {
        debugPrint('TlGate: no TL position — recording a remote validation');
      }

      _report.tlValidatorId = _tlValidatorId;
      _report.tlValidationType = validationType;
      _report.tlValidationPhotoPath = proofPath;
      // A re-validation replaces any previously uploaded proof photo.
      _report.tlValidationPhotoUrl = '';
      await DatabaseService.markTlValidated(_report);
      _finishValidation(
        validationType == 'physical'
            ? 'Validated on site ($distanceLabel)'
            : 'Validated remotely ($distanceLabel)',
      );
    } catch (e, st) {
      debugPrint('TlGate: on-site validation failed: $e\n$st');
      _failValidation('Validation failed');
    }
  }

  /// 'REJECT (Photo + Voice)': the "Dispute Shield". Both a proof photo and a
  /// spoken explanation are mandatory so the rejection stays defensible later.
  /// Cancelling at any step leaves the report untouched in the TO VERIFY tab.
  Future<void> _rejectReport() async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        debugPrint('TlGate: rejection cancelled at the camera step');
        if (mounted) setState(() => _validating = false);
        return;
      }
      final proofPath = await _persistCapture(photo.path);
      if (proofPath.isEmpty) {
        _failValidation('Photo capture failed');
        return;
      }

      if (!mounted) return;
      final voicePath = await showModalBottomSheet<String>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _RejectionVoiceRecorder(),
      );
      if (voicePath == null || voicePath.isEmpty) {
        // No voice note means no defensible rejection: drop the photo and
        // leave the report in the TO VERIFY tab.
        debugPrint('TlGate: rejection cancelled at the voice step');
        try {
          await File(proofPath).delete();
        } catch (e, st) {
          debugPrint('TlGate: rejected proof cleanup failed: $e\\n$st');
        }
        _failValidation('Voice note required to reject');
        return;
      }

      _report.addTimelineEvent(
        actor: 'tl',
        action: 'reject',
        photoUrl: proofPath,
        voiceUrl: voicePath,
      );
      _report.tlValidatorId = _tlValidatorId;
      _report.tlValidationType = 'rejected';
      // A rejection has its own proof media; clear the on-site validation
      // photo so a stale one can never be mistaken for this decision's proof.
      _report.tlValidationPhotoPath = '';
      _report.tlValidationPhotoUrl = '';
      // A re-rejection replaces any previously captured proof media.
      _report.tlRejectionPhotoPath = proofPath;
      _report.tlRejectionPhotoUrl = '';
      _report.tlRejectionVoicePath = voicePath;
      _report.tlRejectionVoiceUrl = '';
      await DatabaseService.markTlValidated(_report);
      debugPrint('TlGate: report ${_report.id} rejected (photo + voice)');
      _finishValidation('Report rejected');
    } catch (e, st) {
      debugPrint('TlGate: rejection failed: $e\\n$st');
      _failValidation('Rejection failed');
    }
  }

  /// Shared success path: notify, close the screen (the History stream
  /// refreshes itself) and push the decision to Supabase in the background.
  void _finishValidation(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    }
    // Offline-first: no-ops offline and is retried on the next sync trigger.
    unawaited(SyncService.syncPendingReports());
  }

  /// Shared failure path: report why and re-enable the gate buttons.
  void _failValidation(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _validating = false);
  }

  /// Compresses a raw camera capture into a small persistent JPEG inside
  /// `<documents>/reports` and returns its absolute path ('' on failure).
  /// Mirrors the Home screen capture flow so uploads stay light on slow links.
  Future<String> _persistCapture(String rawPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final savedPath =
          '${reportsDir.path}/verify_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
          debugPrint('TlGate: raw capture cleanup failed: $e\n$st');
        }
        debugPrint('TlGate: proof photo stored at ${compressed.path}');
        return compressed.path;
      }
      // Compression failed — keep the original capture if it is usable.
      if (await ReportLocalService.isValidFile(rawPath)) return rawPath;
      return '';
    } catch (e, st) {
      debugPrint('TlGate: persistCapture failed: $e\n$st');
      return '';
    }
  }

  /// The TL's current position, or null when location services/permission are
  /// unavailable. Same guarded lookup used by the report save flow, so a denied
  /// permission degrades to a 'remote' validation instead of blocking the TL.
  Future<Position?> _acquireTlPosition() async {
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

  /// The two giant gate buttons: remote (photo only) and on site (take photo).
  Widget _tlValidationButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _giantButton(
            icon: Icons.cloud_done,
            label: 'VALIDATE REMOTELY (Photo Only)',
            color: Colors.blueGrey.shade700,
            onPressed: _validating ? null : _validateRemotely,
          ),
          const SizedBox(height: 10),
          _giantButton(
            icon: Icons.camera_alt,
            label: 'VALIDATE ON SITE (Take Photo)',
            color: Colors.green.shade700,
            onPressed: _validating ? null : _validateOnSite,
          ),
          const SizedBox(height: 10),
          _giantButton(
            icon: Icons.gpp_bad,
            label: 'REJECT & REQUEST FIX',
            color: Colors.red.shade700,
            onPressed: _validating ? null : _rejectReport,
          ),
          if (_validating) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  /// One full-width, two-line action button (icon above a bold label), sized to
  /// stay readable outdoors even on a short screen.
  Widget _giantButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
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
      debugPrint('ResubmitFlow: failed: $e\n$st');
      _failValidation('Resubmission failed');
    }
  }

  /// The subcontractor's giant green "FIX & RESUBMIT" action bar.
  Widget _fixAndResubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: FilledButton.icon(
          onPressed: _validating ? null : _fixAndResubmit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _validating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.build_circle, size: 26),
          label: Text(
            _validating ? 'SUBMITTING…' : 'FIX & RESUBMIT',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Read-only summary of the gate decision, shown once the report has been
  /// validated (so the TL sees how and when it was signed off).
  Widget _tlValidationCard(Report report) {
    final (icon, color, label) = switch (report.tlValidationType) {
      'physical' => (Icons.verified, Colors.green, 'Validated on site'),
      'remote' => (Icons.cloud_done, Colors.blueGrey, 'Validated remotely'),
      'rejected' => (Icons.gpp_bad, Colors.red, 'Rejected by Team Leader'),
      _ => (Icons.verified, Colors.grey, 'Validated'),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Team Leader · '
                    '${DateFormat('d MMM, hh:mm a').format(report.tlValidatedAt!.toLocal())}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar carries the report identity: id + submission time.
      appBar: AppBar(
        leading: const BackButtonCircle(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report #${_report.id}'),
            Text(
              DateFormat('d MMM, HH:mm').format(_report.timestamp.toLocal()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      // The Execution Timeline: everything the report has been through,
      // oldest first, infinitely scrollable.
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
            return _buildTimeline(latest);
          },
        ),
      ),
      // Pinned, never-scrolling action container (role-based, see below).
      bottomNavigationBar: _bottomActionBar(),
    );
  }

  /// The scrollable Execution Timeline: every event in [timelineEvents] is
  /// rendered as a chat bubble, oldest first. The current TL validation summary
  /// (when present) sits above the bubbles.
  Widget _buildTimeline(Report report) {
    final items = <Widget>[];
    if (report.tlValidatedAt != null &&
        report.tlValidationType != 'rejected') {
      items.add(_tlValidationCard(report));
      items.add(const SizedBox(height: 16));
    }
    for (final raw in report.timelineEvents) {
      try {
        final event = Map<String, dynamic>.from(jsonDecode(raw));
        items.add(_timelineEventBubble(event));
        items.add(const SizedBox(height: 16));
      } catch (e) {
        debugPrint('TimelineFlow: skipping malformed event: $e');
      }
    }
    items.add(_locationCard());
    return ListView(padding: const EdgeInsets.all(16), children: items);
  }

  /// One immutable chat bubble for a single timeline event.
  Widget _timelineEventBubble(Map<String, dynamic> event) {
    final actor = (event['actor'] ?? '').toString();
    final action = (event['action'] ?? '').toString();
    final photoUrl = (event['photoUrl'] ?? '').toString();
    final voiceUrl = (event['voiceUrl'] ?? '').toString();
    final timeStr = (event['time'] ?? '').toString();
    final isSub = actor == 'sub';
    final isReject = action == 'reject';
    final when = DateTime.tryParse(timeStr)?.toLocal();
    final media = ReportLocalService.resolveMedia(photoUrl, '');
    final voiceMedia = ReportLocalService.resolveMedia(voiceUrl, '');
    final hasPhoto = media.origin != MediaOrigin.none;
    final hasVoice = voiceMedia.origin != MediaOrigin.none;
    return Align(
      alignment: isSub ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: isSub
              ? Colors.blue.shade50
              : isReject
                  ? Colors.red.shade50
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: isReject
              ? Border.all(color: Colors.red, width: 2)
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSub ? Icons.engineering_outlined : Icons.gavel,
                  size: 18,
                  color: isReject ? Colors.red : Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSub ? 'Subcontractor' : 'Team Leader',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isReject ? Colors.red : Colors.blueGrey,
                    ),
                  ),
                ),
                if (when != null)
                  Text(
                    DateFormat('d MMM, HH:mm').format(when),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _buildEventPhoto(media.location, media.origin == MediaOrigin.network),
                ),
              ),
            ],
            if (hasVoice) ...[
              const SizedBox(height: 8),
              TimelineAudioPlayer(
                voicePath: voiceUrl,
                voiceUrl: voiceUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventPhoto(String location, bool isNetwork) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: location,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) =>
            Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
      );
    }
    return Image.file(
      File(location),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
    );
  }
  /// The report's life story ("Fix & Resubmit" loop): one dot-line per entry.
  Widget _locationCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openInMaps,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 24, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Location Captured',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  /// Pinned, never-scrolling action container. Priority (first match wins):
  ///  1. Closed by the owner -> disabled banner, nobody can act on it;
  ///  2. Team Leader + pending gate -> the three giant decision buttons;
  ///  3. Subcontractor + a live rejection -> the green FIX & RESUBMIT bar.
  Widget? _bottomActionBar() {
    final Widget? content;
    if (_report.ownerStatus == 'validated') {
      content = _closedBanner();
    } else if (widget.isTeamLeader) {
      content = widget.validationMode && widget.report.needsTlValidation
          ? _tlValidationButtons()
          : null;
    } else if (_report.isTlRejected) {
      content = _fixAndResubmitButton();
    } else {
      content = null;
    }
    if (content == null) return null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(child: content),
    );
  }

  /// Disabled banner shown once the owner validated the work: the report is
  /// closed and every action is hidden.
  Widget _closedBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'Work Validated and Closed',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
class _RejectionVoiceRecorder extends StatefulWidget {
  const _RejectionVoiceRecorder();

  @override
  State<_RejectionVoiceRecorder> createState() =>
      _RejectionVoiceRecorderState();
}

class _RejectionVoiceRecorderState extends State<_RejectionVoiceRecorder> {
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
      debugPrint('RejectFlow: voice recording failed: $e\\n$st');
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
            debugPrint('RejectFlow: voice file probe failed: $e\\n$st');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      if (mounted) Navigator.of(context).pop(valid ? path : null);
    } catch (e, st) {
      debugPrint('RejectFlow: voice stop failed: $e\\n$st');
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
      debugPrint('RejectFlow: voice cancel failed: $e\\n$st');
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
