import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
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
import '../widgets/report_thumbnail.dart';
import '../widgets/voice_equalizer.dart';
import '../widgets/voice_play_button.dart';

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
            label: 'REJECT (Photo + Voice)',
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

  /// Toggle playback. Creates (once) and subscribes to a persistent player so
  /// the UI can animate while audio is active and reset when it finishes.
  ///
  /// "Hybrid Shield": plays the local file while it exists, otherwise streams
  /// the cloud copy (a reclaimed report keeps only its URL).
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player?.pause();
      return;
    }
    final media = ReportLocalService.resolveMedia(
      _report.voicePath,
      _report.voiceUrl,
    );
    if (media.origin == MediaOrigin.none) {
      // Either there is no voice note at all, or its local file is gone and
      // there is no cloud copy to stream.
      final missingFile = _report.voicePath.isNotEmpty;
      debugPrint(
        'PlaybackFlow: no playable voice source '
        '(path="${_report.voicePath}", url="${_report.voiceUrl}")',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missingFile ? 'Voice file missing' : 'No voice note'),
        ),
      );
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
      await player.play(
        media.origin == MediaOrigin.localFile
            ? DeviceFileSource(media.location)
            : UrlSource(media.location),
      );
    } catch (e, st) {
      debugPrint('PlaybackFlow: play failed for "${media.location}": $e\n$st');
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
            // "Hybrid Shield": a reclaimed report keeps only its cloud URL, so
            // whether a note exists is decided by the resolver, not the path.
            final hasVoice =
                ReportLocalService.resolveMedia(
                  latest.voicePath,
                  latest.voiceUrl,
                ).origin !=
                MediaOrigin.none;
            return Column(
              children: [
                Expanded(
                  child: ReportThumbnail(
                    report: latest,
                    fit: BoxFit.contain,
                    iconSize: 80,
                  ),
                ),
                if (!hasVoice)
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
                // "Chef de Chantier Gate" decision summary (only once done).
                if (latest.tlValidatedAt != null) _tlValidationCard(latest),
              ],
            );
          },
        ),
      ),
      // "Chef de Chantier Gate": the three giant TL decision buttons stay
      // pinned to the bottom edge so they are always reachable. They only
      // exist for Team Leaders, and only for reports still awaiting a gate
      // decision — a subcontractor opening their own report never sees them.
      bottomNavigationBar:
          widget.validationMode &&
              widget.isTeamLeader &&
              widget.report.needsTlValidation
          ? SafeArea(child: _tlValidationButtons())
          : null,
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
