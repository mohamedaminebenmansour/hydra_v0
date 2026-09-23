import 'package:flutter/material.dart';

import '../models/report.dart';
import 'report_thumbnail.dart';
import 'timeline_audio_player.dart';

// ---------------------------------------------------------------------------
// "Material Reception": the delivery evidence, pinned at the bottom of the
// thread.
//
// The reception capture is deliberately NOT a chat event: it is the report's
// own media ([Report.receptionPhotoPath] / [Report.receptionVoicePath] and their
// cloud copies), so it renders as one block under the thread — the photo of what
// was delivered, the voice note that explains what is wrong with it, and the
// binary verdict (accepted -> green, issue reported -> red delivery dispute).
//
// Everything resolves through the Hybrid Shield helpers (`ReportThumbnail`,
// `TimelineAudioPlayer`), so the block works offline from the local files and
// keeps working after they are reclaimed, from the cloud copies.
// ---------------------------------------------------------------------------

/// The reception verdict as (color, icon, label): green for an accepted
/// delivery, red for a reported issue — the state the Owner must see.
(Color, IconData, String) receptionVerdictStyle(Report report) {
  final disputed = report.hasDeliveryDispute;
  return disputed
      ? (Colors.red.shade700, Icons.report_problem, 'DELIVERY ISSUE REPORTED')
      : (Colors.green.shade700, Icons.inventory_2, 'MATERIAL RECEIVED');
}

/// The reception photo + voice note with its verdict, or an empty box when the
/// report never went through the reception flow.
class ReceptionMediaBlock extends StatelessWidget {
  const ReceptionMediaBlock({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    if (!report.hasReceptionMedia) return const SizedBox.shrink();

    final (color, icon, label) = receptionVerdictStyle(report);
    final hasPhoto =
        report.receptionPhotoPath.isNotEmpty ||
        report.receptionPhotoUrl.isNotEmpty;
    final hasVoice =
        report.receptionVoicePath.isNotEmpty ||
        report.receptionVoiceUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: ReportThumbnail(
                  report: report,
                  pathOverride: report.receptionPhotoPath,
                  urlOverride: report.receptionPhotoUrl,
                  fit: BoxFit.cover,
                  iconSize: 28,
                ),
              ),
            ),
          ],
          if (hasVoice) ...[
            const SizedBox(height: 8),
            TimelineAudioPlayer(
              voicePath: report.receptionVoicePath,
              voiceUrl: report.receptionVoiceUrl,
            ),
          ],
        ],
      ),
    );
  }
}
