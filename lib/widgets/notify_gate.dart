import 'package:flutter/material.dart';

/// One SnackBar, guarded so a popped context can never crash a flow.
///
/// Lives in its own file (instead of `report_sheet_actions.dart`) so feature
/// modules like "Material Reception" can report without importing the action
/// library — which imports the detail sheet, which would close an import cycle.
void notifyGate(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
