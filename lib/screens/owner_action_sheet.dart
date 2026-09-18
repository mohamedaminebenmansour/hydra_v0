import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/timeline_audio_player.dart';

// ---------------------------------------------------------------------------
// Shared row contract
//
// The Owner Command Center is a thin client: it never builds an Isar model, so
// every value it shows is read straight from a Supabase `reports` row. These
// helpers are the single place where a raw row is interpreted; they live here
// (rather than in `owner_home_screen.dart`) because the map screen and this
// sheet both need them, and the screen already imports this file.
// ---------------------------------------------------------------------------

/// Writes one Owner decision straight to the cloud row (`reports.owner_status`).
///
/// [localId] is the row's `local_id` — the same key `SyncService` uses when it
/// pulls the owner's decision back into the field devices. Injected in tests so
/// the sheet can be exercised without a network.
typedef OwnerDecisionWriter =
    Future<void> Function(String localId, String ownerStatus);

/// Thrown by the default writer when the device has no connectivity, so the
/// sheet can show the exact "connect and try again" message.
class OwnerOfflineException implements Exception {
  const OwnerOfflineException([this.message = 'Offline']);

  final String message;

  @override
  String toString() => 'OwnerOfflineException: $message';
}

/// Owner-status vocabulary. Kept identical to the local `Report.ownerStatus`
/// values so the field devices' Smart Pull maps a decision back 1:1.
const String ownerPendingStatus = 'pending';
const String ownerValidatedStatus = 'validated';
const String ownerAcknowledgedStatus = 'acknowledged';
const String ownerOrderedStatus = 'ordered';
const String ownerRejectedStatus = 'rejected';

/// The reject button is always the same red, whatever the report type is.
const Color ownerRejectColor = Colors.red;

/// Reads a row's `owner_status`, defaulting to `'pending'` when the column is
/// missing, null or empty (legacy rows created before the owner workflow
/// existed must still be actionable).
String ownerStatusOf(Map<String, dynamic> row) {
  final raw = (row['owner_status'] ?? '').toString().trim();
  return raw.isEmpty ? ownerPendingStatus : raw;
}

/// The row's `local_id` as a string ('' when the remote row has none).
String ownerLocalIdOf(Map<String, dynamic> row) =>
    (row['local_id'] ?? '').toString();

/// The emoji pinned on the map and shown in the sheet header for a report type.
String ownerTypeEmoji(String type) => switch (type) {
  'problem' => '⚠️',
  'material' => '📦',
  _ => '🔨',
};

/// The plain word for a report type ('Work', 'Problem', 'Material').
String ownerTypeLabel(String type) => switch (type) {
  'problem' => 'Problem',
  'material' => 'Material',
  _ => 'Work',
};

/// The row's submission time in local time, or null when unparsable.
DateTime? ownerTimestampOf(Map<String, dynamic> row) =>
    DateTime.tryParse((row['timestamp'] ?? '').toString())?.toLocal();

/// The Team Leader verification badge: (color, label).
/// Green when the TL verified it (on site or remotely), red on a rejection.
(Color, String) ownerTlBadgeFor(String tlValidationType) =>
    switch (tlValidationType) {
      'physical' => (Colors.green, '✓ TL Verified On Site'),
      'remote' => (Colors.green, '✓ TL Verified Remotely'),
      'rejected' => (Colors.red, 'TL Rejected'),
      _ => (Colors.amber.shade800, 'TL Not Verified Yet'),
    };

/// The TL's rejection proof photo URL (falling back to the on-site validation
/// photo), so the owner can see the evidence behind a rejection.
String ownerTlRejectionPhotoOf(Map<String, dynamic> row) {
  final rejection = (row['tl_rejection_photo_url'] ?? '').toString();
  if (rejection.isNotEmpty) return rejection;
  return (row['tl_validation_photo_url'] ?? '').toString();
}

/// The giant primary decision button for a report [type]:
/// work -> VALIDATE (green), problem -> ACKNOWLEDGE (blue),
/// material -> ORDER (orange).
({String label, String status, Color color, IconData icon})
ownerPrimaryActionFor(String type) => switch (type) {
  'problem' => (
    label: 'ACKNOWLEDGE',
    status: ownerAcknowledgedStatus,
    color: Colors.blue,
    icon: Icons.visibility,
  ),
  'material' => (
    label: 'ORDER',
    status: ownerOrderedStatus,
    color: Colors.orange,
    icon: Icons.local_shipping,
  ),
  _ => (
    label: 'VALIDATE',
    status: ownerValidatedStatus,
    color: Colors.green,
    icon: Icons.check_circle,
  ),
};

/// The word shown on the disabled banner once the owner has decided.
String ownerStatusWord(String ownerStatus) => switch (ownerStatus) {
  'validated' => 'Validated',
  'approved' => 'Approved',
  'acknowledged' => 'Acknowledged',
  'ordered' => 'Ordered',
  'rejected' => 'Rejected',
  _ => 'Waiting',
};

/// Icon + color of the disabled banner, mirroring the status colors used on the
/// map pins.
(IconData, Color) ownerStatusBadgeFor(String ownerStatus) =>
    switch (ownerStatus) {
      'validated' || 'approved' => (Icons.verified, Colors.green),
      'acknowledged' => (Icons.visibility, Colors.blue),
      'ordered' => (Icons.local_shipping, Colors.orange),
      'rejected' => (Icons.cancel, Colors.red),
      _ => (Icons.hourglass_top, Colors.amber.shade800),
    };

// ---------------------------------------------------------------------------
// The action sheet
// ---------------------------------------------------------------------------

/// Shows the Owner's decision sheet for one report row.
///
/// Returns `true` when a decision was saved to Supabase: the caller then
/// re-fetches the reports so the map (pin + cluster colors) reflects it.
Future<bool?> showOwnerActionSheet(
  BuildContext context, {
  required Map<String, dynamic> row,
  required OwnerDecisionWriter writeDecision,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => OwnerActionSheet(row: row, writeDecision: writeDecision),
  );
}

/// The Owner's full-screen-shaped decision sheet ("4-year-old rule"):
/// photo on top, one-glance facts in the middle, two giant buttons at the
/// bottom. Once a report has been decided the buttons disappear and a disabled
/// banner states the current status instead.
class OwnerActionSheet extends StatefulWidget {
  const OwnerActionSheet({
    super.key,
    required this.row,
    required this.writeDecision,
  });

  /// The raw Supabase row (nothing is persisted locally).
  final Map<String, dynamic> row;

  /// Where the decision goes. Defaults are wired by the map screen.
  final OwnerDecisionWriter writeDecision;

  @override
  State<OwnerActionSheet> createState() => _OwnerActionSheetState();
}

class _OwnerActionSheetState extends State<OwnerActionSheet> {
  /// True while a decision is being written: every button is disabled and the
  /// tapped one shows a spinner instead of its icon.
  bool _busy = false;

  /// The status currently being written (which button shows the spinner).
  String? _pendingStatus;

  /// Share of the screen height given to the subcontractor's photo.
  static const double _photoFraction = 0.40;

  String get _status => ownerStatusOf(widget.row);

  bool get _isPending => _status == ownerPendingStatus;

  /// Sends the decision to Supabase. On success the sheet closes and reports
  /// `true`; on failure it stays open, re-enables the buttons and explains
  /// what happened (offline gets its own message).
  Future<void> _decide(String ownerStatus) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pendingStatus = ownerStatus;
    });
    try {
      await widget.writeDecision(ownerLocalIdOf(widget.row), ownerStatus);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('OwnerCommand: decision "$ownerStatus" failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pendingStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is OwnerOfflineException
                ? 'Offline — decision not saved. Connect and try again.'
                : 'Could not save the decision — check your connection.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.row['type'] ?? 'work').toString();
    final tlType = (widget.row['tl_validation_type'] ?? '').toString();
    final voiceUrl = (widget.row['voice_url'] ?? '').toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _photo(MediaQuery.sizeOf(context).height * _photoFraction),
        // The middle block scrolls so small phones can never clip the facts or
        // push the giant buttons off-screen.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(type),
                const SizedBox(height: 14),
                _tlBadge(tlType),
                if (voiceUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TimelineAudioPlayer(voicePath: '', voiceUrl: voiceUrl),
                ],
              ],
            ),
          ),
        ),
        _actionBar(type),
      ],
    );
  }

  /// Top 40%: the subcontractor's proof photo, fetched (and cached) by the
  /// phone straight from the cloud — no local database involved.
  Widget _photo(double height) {
    final photoUrl = (widget.row['photo_url'] ?? '').toString();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoUrl.isEmpty)
            _photoPlaceholder(Icons.image_not_supported)
          else
            CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              placeholder: (context, imageUrl) =>
                  _photoPlaceholder(Icons.photo_camera, loading: true),
              errorWidget: (context, imageUrl, error) =>
                  _photoPlaceholder(Icons.broken_image),
            ),
          // A giant, obvious way out (the sheet is also swipe/tap dismissible).
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.close, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grey fallback tile shared by the photo, the rejection thumbnail and the
  /// full-size viewer.
  Widget _photoPlaceholder(IconData icon, {bool loading = false}) => Container(
    color: loading ? Colors.grey.shade200 : Colors.grey.shade300,
    alignment: Alignment.center,
    child: loading
        ? const CircularProgressIndicator()
        : Icon(icon, size: 64, color: Colors.grey.shade600),
  );

  /// Type (emoji + word) on the left, submission time on the right.
  Widget _header(String type) {
    final timestamp = ownerTimestampOf(widget.row);
    return Row(
      children: [
        Text(ownerTypeEmoji(type), style: const TextStyle(fontSize: 34)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ownerTypeLabel(type),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          timestamp == null
              ? '—'
              : DateFormat('d MMM, HH:mm').format(timestamp),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// The Team Leader verification badge, plus the TL's rejection proof photo
  /// when the report was rejected ("Dispute Shield" evidence).
  Widget _tlBadge(String tlValidationType) {
    final (color, label) = ownerTlBadgeFor(tlValidationType);
    final rejectionPhoto = ownerTlRejectionPhotoOf(widget.row);
    final showProof =
        tlValidationType == 'rejected' && rejectionPhoto.isNotEmpty;
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        if (showProof) ...[
          const SizedBox(width: 12),
          _rejectionThumb(rejectionPhoto),
        ],
      ],
    );
  }

  /// Tiny thumbnail of the TL's rejection photo; tapping it opens the full-size
  /// proof so the owner can judge the dispute before deciding.
  Widget _rejectionThumb(String url) {
    return GestureDetector(
      onTap: () => _showFullPhoto(url),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, imageUrl) =>
              _photoPlaceholder(Icons.photo_camera, loading: true),
          errorWidget: (context, imageUrl, error) =>
              _photoPlaceholder(Icons.broken_image),
        ),
      ),
    );
  }

  /// Full-size look at a proof photo (tap anywhere to close).
  void _showFullPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, imageUrl) =>
                const CircularProgressIndicator(),
            errorWidget: (context, imageUrl, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }

  /// Bottom, always-visible decision bar: two giant full-width buttons while
  /// the report is pending, a disabled banner once it has been decided.
  Widget _actionBar(String type) {
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _isPending ? _decisionButtons(type) : _closedBanner(),
        ),
      ),
    );
  }

  /// The context-aware pair of giant buttons: the primary action depends on the
  /// report type (work / problem / material), reject is always offered.
  Widget _decisionButtons(String type) {
    final primary = ownerPrimaryActionFor(type);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _decisionButton(
          label: primary.label,
          color: primary.color,
          icon: primary.icon,
          ownerStatus: primary.status,
        ),
        const SizedBox(height: 10),
        _decisionButton(
          label: 'REJECT',
          color: ownerRejectColor,
          icon: Icons.close,
          ownerStatus: ownerRejectedStatus,
        ),
      ],
    );
  }

  /// One giant 76px button; the tapped one swaps its icon for a spinner while
  /// the write is in flight, and both are disabled meanwhile.
  Widget _decisionButton({
    required String label,
    required Color color,
    required IconData icon,
    required String ownerStatus,
  }) {
    final loading = _busy && _pendingStatus == ownerStatus;
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : () => _decide(ownerStatus),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, size: 34, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
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

  /// Shown instead of the buttons once the report has been decided: the owner
  /// can read the status but cannot act twice.
  Widget _closedBanner() {
    final (icon, color) = ownerStatusBadgeFor(_status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: 6),
          Text(
            ownerStatusWord(_status),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Already decided — nothing left to do here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
