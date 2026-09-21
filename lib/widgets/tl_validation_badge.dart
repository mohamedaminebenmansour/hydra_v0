import 'package:flutter/material.dart';

import '../models/report.dart';

/// The Team Leader's validation verdict as a `(color, icon, label)` triple.
///
/// The Visual Badge vocabulary — instantly readable without parsing text:
/// - never validated  -> yellow hourglass   'TL: Pending'
/// - `physical`       -> green verified     'TL: On Site'
/// - `remote`         -> blue visibility    'TL: Remote'
/// - `rejected`       -> red close          'TL: Rejected'
///
/// Shared by the History tracker node and the report detail header so both
/// surfaces always show the exact same icon, colour and wording.
(Color, IconData, String) tlValidationBadgeStyle(Report report) {
  // Not validated yet (the report sits in the TL's 'TO VERIFY' queue).
  if (report.tlValidatedAt == null) {
    return (Colors.yellow.shade800, Icons.hourglass_top, 'TL: Pending');
  }
  return switch (report.tlValidationType) {
    // The TL stood within 50 m of the report pin: verified on site.
    'physical' => (Colors.green, Icons.verified, 'TL: On Site'),
    // Photo-only check from the office: verified remotely.
    'remote' => (Colors.blue, Icons.visibility, 'TL: Remote'),
    // Dispute Shield: the TL rejected and asked for a fix.
    'rejected' => (Colors.red, Icons.close, 'TL: Rejected'),
    // A timestamp without a type is a data anomaly — treat as pending.
    _ => (Colors.yellow.shade800, Icons.hourglass_top, 'TL: Pending'),
  };
}

/// The pill-shaped TL validation badge: a small icon + tiny bold label on the
/// verdict colour (tinted background), matching the stage-chip style used in
/// the report detail header.
///
/// Both the icon and the label ellipsize instead of overflowing: the outer
/// row is [MainAxisSize.min] and the label is wrapped in a [Flexible], so the
/// badge shrinks gracefully inside any Row it is dropped into.
class TlValidationBadge extends StatelessWidget {
  const TlValidationBadge({
    super.key,
    required this.report,
    this.iconSize = 14,
    this.fontSize = 11,
  });

  final Report report;

  final double iconSize;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = tlValidationBadgeStyle(report);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}