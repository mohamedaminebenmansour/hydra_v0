/// The signed-in user's role, injected at build/run time:
/// `flutter run --dart-define=USER_ROLE=team_leader`.
///
/// Lives in its own file (instead of `main.dart`) so screens can read it
/// without creating an import cycle back through `main.dart`.
///
/// 'subcontractor' gets the capture screen; 'team_leader' gets the Chef de
/// Chantier dashboard. Anything else falls back to the subcontractor UI.
const String userRole = String.fromEnvironment(
  'USER_ROLE',
  defaultValue: 'subcontractor',
);