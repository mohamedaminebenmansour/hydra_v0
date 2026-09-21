import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import 'report_thumbnail.dart';
import 'tl_validation_badge.dart';

// ---------------------------------------------------------------------------
// The shared, glanceable report card.
//
// One card, two screens: the field History list (subcontractor / Team Leader)
// and the Owner's "Audit & Reports" Executive List both render this widget so
// the validation story — the Visual Badges (TL On Site vs Remote, Owner
// decision) — looks and reads identically everywhere. The card is fully
// data-driven from the [Report]; only the tap handler and two flags differ
// per screen.
// ---------------------------------------------------------------------------

/// Short, locale-friendly label for an optional timestamp, e.g. '9 Sep, 10:00'.
/// Returns '' for null so tracker nodes can omit the time column.
String trackerTimeLabel(DateTime? time) {
  if (time == null) return '';
  return DateFormat('d MMM, HH:mm').format(time.toLocal());
}

/// Day-group header for a local timestamp: 'TODAY', 'YESTERDAY', or a long
/// date ('Friday, 14 September') for anything older. Shared by the History
/// screen and the Owner's Executive List so both group the cards alike.
String dayGroupLabel(DateTime local) {
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final now = DateTime.now();
  if (isSameDay(local, now)) return 'TODAY';
  final yesterday = now.subtract(const Duration(days: 1));
  if (isSameDay(local, yesterday)) return 'YESTERDAY';
  return DateFormat('EEEE, d MMMM').format(local);
}

/// TL gate verdict as a (color, icon, label, timestamp) tuple for the tracker.
/// The badge vocabulary (colour + icon + wording) is defined once in
/// [tlValidationBadgeStyle] so the History card and the report detail header
/// always agree.
(Color, IconData, String, DateTime?) trafficTlNode(Report report) {
  final (color, icon, label) = tlValidationBadgeStyle(report);
  return (color, icon, label, report.tlValidatedAt);
}

/// Whether the TL verdict surfaces a dispute bubble on the tracker node.
bool trafficTlHasDispute(Report report) =>
    report.tlValidationType == 'rejected';

/// Owner decision as a (color, label, timestamp) tuple for the tracker.
(Color, String, DateTime?) trafficOwnerNode(Report report) {
  final ts = report.ownerStatusAt;
  return switch (report.ownerStatus) {
    'validated' || 'approved' => (Colors.green, 'Validated', ts),
    'acknowledged' => (Colors.blue, 'Acknowledged', ts),
    'ordered' => (Colors.orange, 'Ordered', ts),
    'rejected' => (Colors.red, 'Rejected', ts),
    _ => (Colors.yellow, 'Waiting', null),
  };
}

/// Border color of the card thumbnail, from the ownerStatus:
/// Yellow=pending, Green=validated/acknowledged, Orange=ordered, Red=rejected.
Color trafficBorderColor(String ownerStatus) => switch (ownerStatus) {
  'validated' || 'acknowledged' => Colors.green,
  'ordered' => Colors.orange,
  'rejected' => Colors.red,
  _ => Colors.yellow,
};

/// Icon matching each owner status for the tracker's leading glyph —
/// a replacement for the old anonymous colored dot.
IconData trafficOwnerNodeIcon(String ownerStatus) => switch (ownerStatus) {
  'validated' || 'acknowledged' => Icons.verified,
  'ordered' => Icons.shopping_cart,
  'rejected' => Icons.close,
  _ => Icons.hourglass_top,
};

/// The card's dominant type icon, colored like the map pins.
IconData trafficTypeIcon(String type) => switch (type) {
  'work' => Icons.build,
  'problem' => Icons.warning,
  _ => Icons.inventory,
};

Color trafficTypeColor(String type) => switch (type) {
  'work' => Colors.grey,
  'problem' => Colors.red,
  _ => Colors.amber,
};

// The tracker widgets and the [TrafficCard] itself follow below.

/// One tracker node: a fixed 18x18 leading icon + small label + optional
/// timestamp + optional dispute bubble. Every text can ellipsize, so a narrow
/// card can never pixel-overflow.
Widget _trackerNode({
  required Widget leading,
  required String label,
  DateTime? time,
  bool showDisputeBubble = false,
}) {
  final timeText = trackerTimeLabel(time);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 18, height: 18, child: Center(child: leading)),
      const SizedBox(width: 6),
      Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                timeText,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      if (showDisputeBubble) ...[
        const SizedBox(width: 4),
        Icon(Icons.chat_bubble_outline, size: 13, color: Colors.red),
      ],
    ],
  );
}

/// Thin connector between tracker nodes so the 3 steps read as a timeline.
Widget _trackerConnector() => Container(
  width: 2,
  height: 6,
  margin: const EdgeInsets.only(left: 8),
  color: Colors.grey.shade300,
);

/// The vertical Submitted -> TL -> Owner tracker. The TL step is HIDDEN for
/// the Team Leader (they are the TL), who only tracks the Owner handoff.
Widget reportValidationTracker(Report report, {bool isTeamLeader = false}) {
  final (tlColor, tlIcon, tlLabel, tlTime) = trafficTlNode(report);
  final (ownerColor, ownerLabel, ownerTime) = trafficOwnerNode(report);
  final nodes = <Widget>[
    _trackerNode(
      leading: Icon(Icons.check_circle, size: 16, color: Colors.grey),
      label: 'Submitted',
      time: report.timestamp,
    ),
    // Node 2: Team Leader gate - the verdict is a Visual Badge (icon +
    // colour) so Physical vs Remote is readable without reading text.
    if (!isTeamLeader)
      _trackerNode(
        leading: Icon(tlIcon, size: 16, color: tlColor),
        label: tlLabel,
        time: tlTime,
        showDisputeBubble: trafficTlHasDispute(report),
      ),
    // Node 3: Owner decision - visible to all roles, as a matching Material
    // icon in the owner-status colour.
    _trackerNode(
      leading: Icon(
        trafficOwnerNodeIcon(report.ownerStatus),
        size: 16,
        color: ownerColor,
      ),
      label: ownerLabel,
      time: ownerTime,
    ),
  ];
  final out = <Widget>[];
  for (var i = 0; i < nodes.length; i++) {
    if (i > 0) out.add(_trackerConnector());
    out.add(nodes[i]);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: out,
  );
}

/// One glanceable, icon-dominant report tile: a 100x100 photo on the left with
/// the ownerStatus border, a giant type icon on the right, and the 3-node
/// validation tracker (Submitted -> TL -> Owner) underneath.
class TrafficCard extends StatelessWidget {
  const TrafficCard({
    super.key,
    required this.report,
    this.isTeamLeader = false,
    this.showUnreadDot = true,
    this.onTap,
  });

  final Report report;

  /// The Team Leader sees their own gate collapsed (they ARE the TL).
  final bool isTeamLeader;

  /// The Owner's thin-client reports carry no read state; their list turns
  /// the WhatsApp-style unread dot off.
  final bool showUnreadDot;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = trafficBorderColor(report.ownerStatus);
    final thumb = ReportThumbnail(report: report, size: 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 100x100 photo with the thick owner-status border - no overlays.
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 3.0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: thumb,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right side: dominant type icon + the 3-node validation tracker.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          trafficTypeIcon(report.type),
                          size: 28,
                          color: trafficTypeColor(report.type),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: reportValidationTracker(
                            report,
                            isTeamLeader: isTeamLeader,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The unread dot (WhatsApp-style): something new happened on the
            // thread — a TL rejection, a resubmission, an owner decision —
            // and the user has not opened the sheet since.
            if (showUnreadDot && !report.isReadByUser)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  key: const Key('history_unread_dot'),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
