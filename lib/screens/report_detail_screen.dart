import 'package:flutter/material.dart';

import '../models/report.dart';
import '../role.dart';
import '../widgets/report_detail_bottom_sheet.dart';
import '../widgets/report_sheet_actions.dart';

// The on-site distance classifier moved to `report_sheet_actions.dart`; it is
// re-exported here so the existing imports and tests keep compiling.
export '../widgets/report_sheet_actions.dart'
    show tlPhysicalRadiusMeters, tlValidationTypeForDistance;

/// Shows a single Report with the photo and a play button for its voice note.
///
/// Since the reusable [ReportDetailBottomSheet] exists, this screen is only a
/// thin full-page host around it — same photo, timestamp, GPS coordinates,
/// validation status and read-only Subcontractor <-> Team Leader thread, whether
/// it is opened from the History list, the map or the Team Leader dashboard.
///
/// The bottom bar comes from the signed-in role alone: a Team Leader gets the
/// giant APPROVE / REJECT buttons on a report still awaiting the gate, and a
/// subcontractor gets FIX & RESUBMIT on a report the TL rejected.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    this.userRoleOverride,
  });

  final Report report;

  /// Test seam for the compile-time role. Null falls back to the [userRole]
  /// dart-define; tests pass 'team_leader' or 'subcontractor' to exercise both
  /// roles in one plain `flutter test` run.
  final String? userRoleOverride;

  /// True when the signed-in user is a Team Leader. The gate buttons are
  /// exclusive to that role — a subcontractor opening their own report can
  /// never validate or reject it.
  bool get isTeamLeader => (userRoleOverride ?? userRole) == 'team_leader';

  /// The giant buttons shown at the bottom of the sheet, resolved by the shared
  /// [defaultActionsFor] rule (same logic as the History list, the map and the
  /// Team Leader dashboard). [userRoleOverride] is forwarded so tests can
  /// exercise both roles in one plain `flutter test` run.
  ReportSheetActions get actions =>
      defaultActionsFor(report, role: userRoleOverride);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ReportDetailBottomSheet(
          report: report,
          watch: defaultWatchReport,
          actions: actions,
          selfActor: isTeamLeader ? 'tl' : 'sub',
        ),
      ),
    );
  }
}
