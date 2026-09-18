import 'package:flutter/material.dart';

import '../models/report.dart';
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
/// validation status and Subcontractor <-> Team Leader thread, whether it is
/// opened from the History list, the map or the Team Leader dashboard.
///
/// When opened from the History 'TO VERIFY' tab ([validationMode] is true) it
/// also hosts the "Chef de Chantier Gate": three giant Team Leader decision
/// buttons (validate remotely, validate on site, reject) at the bottom.
class ReportDetailScreen extends StatelessWidget {
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

  /// The giant buttons shown at the bottom of the sheet, resolved by the
  /// shared [defaultActionsFor] rule (same logic as the History list, the map
  /// and the Team Leader dashboard). [userRoleOverride] is forwarded so tests
  /// can exercise both roles in one plain `flutter test` run.
  ReportSheetActions get actions => defaultActionsFor(
    report,
    validationMode: validationMode,
    role: userRoleOverride,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ReportDetailBottomSheet(
          report: report,
          watch: defaultWatchReport,
          sendComment: defaultSendComment,
          actions: actions,
          selfActor: isTeamLeader ? 'tl' : 'sub',
        ),
      ),
    );
  }
}
