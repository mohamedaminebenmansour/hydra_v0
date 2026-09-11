import 'package:isar_community/isar.dart';

part 'report.g.dart';

/// A locally stored field report.
///
/// [type] is one of: 'work', 'problem', or 'material'.
@collection
class Report {
  Id id = Isar.autoIncrement;

  /// The kind of report: 'work', 'problem', or 'material'.
  String type = 'work';

  /// Path to the captured photo on the local filesystem.
  String photoPath = '';

  /// Optional path to a voice recording. Empty when none was recorded.
  String voicePath = '';

  /// Latitude of the report location.
  double lat = 0.0;

  /// Longitude of the report location.
  double lng = 0.0;

  /// When the report was created.
  late DateTime timestamp;

  /// Workflow status, defaulting to 'pending'.
  String status = 'pending';
}