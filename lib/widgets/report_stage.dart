import 'package:flutter/material.dart';

import '../models/report.dart';

// ---------------------------------------------------------------------------
// The pure "where is this report right now?" vocabulary.
//
// Extracted from `report_detail_bottom_sheet.dart` so the sheet, the chat
// timeline (`report_timeline.dart`) and the map/history surfaces can all share
// it without a widget -> widget import cycle. The sheet re-exports this file,
// so every existing `import 'report_detail_bottom_sheet.dart';` keeps working.
//
// Nothing here touches storage, the network or a BuildContext: the stage is
// resolved from the report's two independent layers (the Team Leader gate and
// the Owner decision) and rendered as an icon + colour + label.
// ---------------------------------------------------------------------------

/// The six validation states the product talks about, resolved once from the
/// two independent layers (the Team Leader gate and the Owner decision).
///
/// This is the single source of truth for "where is this report right now?" —
/// the sheet renders it as a badge, and the History stepper renders the same
/// value as three nodes.
enum ReportStage {
  pendingTl,
  rejectedByTl,
  validatedByTl,
  pendingOwner,
  rejectedByOwner,
  closedByOwner,
}

/// Owner statuses that mean the owner is done with the report.
///
/// A REJECTION is deliberately NOT here: rejecting does not lock the
/// conversation — the subcontractor (and the Team Leader) can still add
/// timeline events to argue or fix, and the owner keeps his action bar so he
/// can change his mind. Only the positive/neutral decisions close the report.
const Set<String> _closedOwnerStatuses = {
  'validated',
  'approved',
  'acknowledged',
  'ordered',
};

/// True when the Owner has taken a final decision. The owner layer is the last
/// word of the workflow: once closed, a report stops being actionable even if
/// the Team Leader had rejected it earlier in the timeline.
bool isReportClosedByOwner(Report report) =>
    _closedOwnerStatuses.contains(report.ownerStatus);

/// Resolves the report's current stage.
///
/// A closed report is closed (the owner's decision overrides everything), then
/// a Team Leader rejection short-circuits (the report is back with the
/// subcontractor), then the TL gate decides. Reports that never pass the gate
/// ('problem' reports) go straight to the owner layer.
ReportStage reportStageOf(Report report) {
  if (isReportClosedByOwner(report)) return ReportStage.closedByOwner;
  if (report.ownerStatus == 'rejected') return ReportStage.rejectedByOwner;
  if (report.isTlRejected) return ReportStage.rejectedByTl;
  if (report.isTlVerified) return ReportStage.pendingOwner;
  if (!report.needsTlValidation) return ReportStage.pendingOwner;
  return ReportStage.pendingTl;
}

/// Icon, color and label of a stage. The label of [ReportStage.closedByOwner]
/// depends on what the owner actually decided, hence [ownerStatus].
(IconData, Color, String) reportStageStyle(
  ReportStage stage, {
  String ownerStatus = '',
}) => switch (stage) {
  ReportStage.pendingTl => (
    Icons.hourglass_top,
    Colors.orange,
    'Pending TL Validation',
  ),
  ReportStage.rejectedByTl => (
    Icons.gpp_bad,
    Colors.red,
    'Rejected by TL — Needs Fix',
  ),
  ReportStage.validatedByTl => (Icons.verified, Colors.green, 'Approved by TL'),
  ReportStage.pendingOwner => (
    Icons.supervisor_account,
    Colors.blue,
    'Pending Owner Approval',
  ),
  ReportStage.rejectedByOwner => (
    Icons.cancel,
    Colors.red,
    'Rejected by Owner',
  ),
  ReportStage.closedByOwner => switch (ownerStatus) {
    'ordered' => (Icons.local_shipping, Colors.orange, 'Material Ordered'),
    'acknowledged' => (Icons.visibility, Colors.blue, 'Acknowledged by Owner'),
    _ => (Icons.check_circle, Colors.green, 'Approved by Owner'),
  },
};

/// Human wording for a thread event, so a bubble says what happened instead of
/// only showing media.
String reportActionLabel(String action) => switch (action) {
  'submit' => 'Reported',
  'resubmit' => 'Fixed & resubmitted',
  'reject' => 'Rejected',
  'fix_note' => 'Fix explanation',
  'comment' => 'Message',
  _ => 'Update',
};

/// The report-type emoji used on the sheet's type chip (🔨 work, ⚠️ problem,
/// 📦 material).
String reportTypeEmoji(String type) => switch (type) {
  'problem' => '⚠️',
  'material' => '📦',
  _ => '🔨',
};

/// True when the report has reached a state where nobody can act on it any
/// more, so the sheet greys out its action bar with a lock instead of showing
/// decision icons: the Owner already decided, or the Team Leader already
/// signed the report off.
bool reportStaysActionableLock(Report report) =>
    isReportClosedByOwner(report) || report.isTlVerified;
