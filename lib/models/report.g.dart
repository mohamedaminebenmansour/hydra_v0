// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReportCollection on Isar {
  IsarCollection<Report> get reports => this.collection();
}

const ReportSchema = CollectionSchema(
  name: r'Report',
  id: 4107730612455750309,
  properties: {
    r'dbStatus': PropertySchema(
      id: 0,
      name: r'dbStatus',
      type: IsarType.string,
    ),
    r'isDbSynced': PropertySchema(
      id: 1,
      name: r'isDbSynced',
      type: IsarType.bool,
    ),
    r'isFullySynced': PropertySchema(
      id: 2,
      name: r'isFullySynced',
      type: IsarType.bool,
    ),
    r'isPhotoSynced': PropertySchema(
      id: 3,
      name: r'isPhotoSynced',
      type: IsarType.bool,
    ),
    r'isRetryable': PropertySchema(
      id: 4,
      name: r'isRetryable',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(id: 5, name: r'isSynced', type: IsarType.bool),
    r'isVoiceSynced': PropertySchema(
      id: 6,
      name: r'isVoiceSynced',
      type: IsarType.bool,
    ),
    r'lat': PropertySchema(id: 7, name: r'lat', type: IsarType.double),
    r'lng': PropertySchema(id: 8, name: r'lng', type: IsarType.double),
    r'mobileId': PropertySchema(
      id: 9,
      name: r'mobileId',
      type: IsarType.string,
    ),
    r'ownerStatus': PropertySchema(
      id: 10,
      name: r'ownerStatus',
      type: IsarType.string,
    ),
    r'ownerStatusAt': PropertySchema(
      id: 11,
      name: r'ownerStatusAt',
      type: IsarType.dateTime,
    ),
    r'photoPath': PropertySchema(
      id: 12,
      name: r'photoPath',
      type: IsarType.string,
    ),
    r'photoStatus': PropertySchema(
      id: 13,
      name: r'photoStatus',
      type: IsarType.string,
    ),
    r'photoUrl': PropertySchema(
      id: 14,
      name: r'photoUrl',
      type: IsarType.string,
    ),
    r'problemCategory': PropertySchema(
      id: 15,
      name: r'problemCategory',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 16, name: r'status', type: IsarType.string),
    r'supabaseId': PropertySchema(
      id: 17,
      name: r'supabaseId',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 18,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'tlRejectionPhotoPath': PropertySchema(
      id: 19,
      name: r'tlRejectionPhotoPath',
      type: IsarType.string,
    ),
    r'tlRejectionPhotoUrl': PropertySchema(
      id: 20,
      name: r'tlRejectionPhotoUrl',
      type: IsarType.string,
    ),
    r'tlRejectionVoicePath': PropertySchema(
      id: 21,
      name: r'tlRejectionVoicePath',
      type: IsarType.string,
    ),
    r'tlRejectionVoiceUrl': PropertySchema(
      id: 22,
      name: r'tlRejectionVoiceUrl',
      type: IsarType.string,
    ),
    r'tlValidatedAt': PropertySchema(
      id: 23,
      name: r'tlValidatedAt',
      type: IsarType.dateTime,
    ),
    r'tlValidationPhotoPath': PropertySchema(
      id: 24,
      name: r'tlValidationPhotoPath',
      type: IsarType.string,
    ),
    r'tlValidationPhotoUrl': PropertySchema(
      id: 25,
      name: r'tlValidationPhotoUrl',
      type: IsarType.string,
    ),
    r'tlValidationType': PropertySchema(
      id: 26,
      name: r'tlValidationType',
      type: IsarType.string,
    ),
    r'tlValidatorId': PropertySchema(
      id: 27,
      name: r'tlValidatorId',
      type: IsarType.string,
    ),
    r'type': PropertySchema(id: 28, name: r'type', type: IsarType.string),
    r'userId': PropertySchema(id: 29, name: r'userId', type: IsarType.string),
    r'voicePath': PropertySchema(
      id: 30,
      name: r'voicePath',
      type: IsarType.string,
    ),
    r'voiceStatus': PropertySchema(
      id: 31,
      name: r'voiceStatus',
      type: IsarType.string,
    ),
    r'voiceUrl': PropertySchema(
      id: 32,
      name: r'voiceUrl',
      type: IsarType.string,
    ),
  },

  estimateSize: _reportEstimateSize,
  serialize: _reportSerialize,
  deserialize: _reportDeserialize,
  deserializeProp: _reportDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _reportGetId,
  getLinks: _reportGetLinks,
  attach: _reportAttach,
  version: '3.3.2',
);

int _reportEstimateSize(
  Report object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dbStatus.length * 3;
  bytesCount += 3 + object.mobileId.length * 3;
  bytesCount += 3 + object.ownerStatus.length * 3;
  bytesCount += 3 + object.photoPath.length * 3;
  bytesCount += 3 + object.photoStatus.length * 3;
  bytesCount += 3 + object.photoUrl.length * 3;
  bytesCount += 3 + object.problemCategory.length * 3;
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.supabaseId.length * 3;
  bytesCount += 3 + object.tlRejectionPhotoPath.length * 3;
  bytesCount += 3 + object.tlRejectionPhotoUrl.length * 3;
  bytesCount += 3 + object.tlRejectionVoicePath.length * 3;
  bytesCount += 3 + object.tlRejectionVoiceUrl.length * 3;
  bytesCount += 3 + object.tlValidationPhotoPath.length * 3;
  bytesCount += 3 + object.tlValidationPhotoUrl.length * 3;
  bytesCount += 3 + object.tlValidationType.length * 3;
  bytesCount += 3 + object.tlValidatorId.length * 3;
  bytesCount += 3 + object.type.length * 3;
  bytesCount += 3 + object.userId.length * 3;
  bytesCount += 3 + object.voicePath.length * 3;
  bytesCount += 3 + object.voiceStatus.length * 3;
  bytesCount += 3 + object.voiceUrl.length * 3;
  return bytesCount;
}

void _reportSerialize(
  Report object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.dbStatus);
  writer.writeBool(offsets[1], object.isDbSynced);
  writer.writeBool(offsets[2], object.isFullySynced);
  writer.writeBool(offsets[3], object.isPhotoSynced);
  writer.writeBool(offsets[4], object.isRetryable);
  writer.writeBool(offsets[5], object.isSynced);
  writer.writeBool(offsets[6], object.isVoiceSynced);
  writer.writeDouble(offsets[7], object.lat);
  writer.writeDouble(offsets[8], object.lng);
  writer.writeString(offsets[9], object.mobileId);
  writer.writeString(offsets[10], object.ownerStatus);
  writer.writeDateTime(offsets[11], object.ownerStatusAt);
  writer.writeString(offsets[12], object.photoPath);
  writer.writeString(offsets[13], object.photoStatus);
  writer.writeString(offsets[14], object.photoUrl);
  writer.writeString(offsets[15], object.problemCategory);
  writer.writeString(offsets[16], object.status);
  writer.writeString(offsets[17], object.supabaseId);
  writer.writeDateTime(offsets[18], object.timestamp);
  writer.writeString(offsets[19], object.tlRejectionPhotoPath);
  writer.writeString(offsets[20], object.tlRejectionPhotoUrl);
  writer.writeString(offsets[21], object.tlRejectionVoicePath);
  writer.writeString(offsets[22], object.tlRejectionVoiceUrl);
  writer.writeDateTime(offsets[23], object.tlValidatedAt);
  writer.writeString(offsets[24], object.tlValidationPhotoPath);
  writer.writeString(offsets[25], object.tlValidationPhotoUrl);
  writer.writeString(offsets[26], object.tlValidationType);
  writer.writeString(offsets[27], object.tlValidatorId);
  writer.writeString(offsets[28], object.type);
  writer.writeString(offsets[29], object.userId);
  writer.writeString(offsets[30], object.voicePath);
  writer.writeString(offsets[31], object.voiceStatus);
  writer.writeString(offsets[32], object.voiceUrl);
}

Report _reportDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Report();
  object.dbStatus = reader.readString(offsets[0]);
  object.id = id;
  object.lat = reader.readDouble(offsets[7]);
  object.lng = reader.readDouble(offsets[8]);
  object.mobileId = reader.readString(offsets[9]);
  object.ownerStatus = reader.readString(offsets[10]);
  object.ownerStatusAt = reader.readDateTimeOrNull(offsets[11]);
  object.photoPath = reader.readString(offsets[12]);
  object.photoStatus = reader.readString(offsets[13]);
  object.photoUrl = reader.readString(offsets[14]);
  object.problemCategory = reader.readString(offsets[15]);
  object.status = reader.readString(offsets[16]);
  object.supabaseId = reader.readString(offsets[17]);
  object.timestamp = reader.readDateTime(offsets[18]);
  object.tlRejectionPhotoPath = reader.readString(offsets[19]);
  object.tlRejectionPhotoUrl = reader.readString(offsets[20]);
  object.tlRejectionVoicePath = reader.readString(offsets[21]);
  object.tlRejectionVoiceUrl = reader.readString(offsets[22]);
  object.tlValidatedAt = reader.readDateTimeOrNull(offsets[23]);
  object.tlValidationPhotoPath = reader.readString(offsets[24]);
  object.tlValidationPhotoUrl = reader.readString(offsets[25]);
  object.tlValidationType = reader.readString(offsets[26]);
  object.tlValidatorId = reader.readString(offsets[27]);
  object.type = reader.readString(offsets[28]);
  object.userId = reader.readString(offsets[29]);
  object.voicePath = reader.readString(offsets[30]);
  object.voiceStatus = reader.readString(offsets[31]);
  object.voiceUrl = reader.readString(offsets[32]);
  return object;
}

P _reportDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readDateTime(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (reader.readString(offset)) as P;
    case 22:
      return (reader.readString(offset)) as P;
    case 23:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 24:
      return (reader.readString(offset)) as P;
    case 25:
      return (reader.readString(offset)) as P;
    case 26:
      return (reader.readString(offset)) as P;
    case 27:
      return (reader.readString(offset)) as P;
    case 28:
      return (reader.readString(offset)) as P;
    case 29:
      return (reader.readString(offset)) as P;
    case 30:
      return (reader.readString(offset)) as P;
    case 31:
      return (reader.readString(offset)) as P;
    case 32:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _reportGetId(Report object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _reportGetLinks(Report object) {
  return [];
}

void _reportAttach(IsarCollection<dynamic> col, Id id, Report object) {
  object.id = id;
}

extension ReportQueryWhereSort on QueryBuilder<Report, Report, QWhere> {
  QueryBuilder<Report, Report, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReportQueryWhere on QueryBuilder<Report, Report, QWhereClause> {
  QueryBuilder<Report, Report, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Report, Report, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Report, Report, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReportQueryFilter on QueryBuilder<Report, Report, QFilterCondition> {
  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dbStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dbStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dbStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dbStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> dbStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dbStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isDbSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isDbSynced', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isFullySyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFullySynced', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isPhotoSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isPhotoSynced', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isRetryableEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isRetryable', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> isVoiceSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isVoiceSynced', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> latEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lat',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> latGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lat',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> latLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lat',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> latBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lat',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> lngEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lng',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> lngGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lng',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> lngLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lng',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> lngBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lng',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mobileId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mobileId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mobileId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mobileId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> mobileIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'mobileId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'ownerStatusAt'),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'ownerStatusAt'),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerStatusAt', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerStatusAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerStatusAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> ownerStatusAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerStatusAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'photoPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'photoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'photoPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoPath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoPath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'photoStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'photoStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'photoStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'photoUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'photoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'photoUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> photoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  problemCategoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'problemCategory',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'problemCategory',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'problemCategory',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> problemCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'problemCategory', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  problemCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'problemCategory', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'supabaseId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'supabaseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'supabaseId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'supabaseId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> supabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'supabaseId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> timestampEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlRejectionPhotoPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlRejectionPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlRejectionPhotoPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlRejectionPhotoPath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlRejectionPhotoPath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlRejectionPhotoUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlRejectionPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlRejectionPhotoUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlRejectionPhotoUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionPhotoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlRejectionPhotoUrl',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlRejectionVoicePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlRejectionVoicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlRejectionVoicePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlRejectionVoicePath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoicePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlRejectionVoicePath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlRejectionVoiceUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlRejectionVoiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlRejectionVoiceUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlRejectionVoiceUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlRejectionVoiceUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlRejectionVoiceUrl',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'tlValidatedAt'),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'tlValidatedAt'),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlValidatedAt', value: value),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlValidatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlValidatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlValidatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlValidationPhotoPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlValidationPhotoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlValidationPhotoPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlValidationPhotoPath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlValidationPhotoPath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlValidationPhotoUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlValidationPhotoUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlValidationPhotoUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlValidationPhotoUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationPhotoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'tlValidationPhotoUrl',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlValidationType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlValidationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidationTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlValidationType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlValidationType', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidationTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tlValidationType', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tlValidatorId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tlValidatorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tlValidatorId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> tlValidatorIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tlValidatorId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition>
  tlValidatorIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tlValidatorId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'type', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'userId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'userId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'userId', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'voicePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'voicePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'voicePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'voicePath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voicePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'voicePath', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'voiceStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'voiceStatus',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'voiceStatus',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'voiceStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'voiceStatus', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'voiceUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'voiceUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'voiceUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'voiceUrl', value: ''),
      );
    });
  }

  QueryBuilder<Report, Report, QAfterFilterCondition> voiceUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'voiceUrl', value: ''),
      );
    });
  }
}

extension ReportQueryObject on QueryBuilder<Report, Report, QFilterCondition> {}

extension ReportQueryLinks on QueryBuilder<Report, Report, QFilterCondition> {}

extension ReportQuerySortBy on QueryBuilder<Report, Report, QSortBy> {
  QueryBuilder<Report, Report, QAfterSortBy> sortByDbStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dbStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByDbStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dbStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsDbSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDbSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsDbSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDbSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsFullySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFullySynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsFullySyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFullySynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsPhotoSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPhotoSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsPhotoSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPhotoSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetryable', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsRetryableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetryable', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsVoiceSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isVoiceSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByIsVoiceSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isVoiceSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByMobileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByMobileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByOwnerStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByOwnerStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByOwnerStatusAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatusAt', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByOwnerStatusAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatusAt', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByProblemCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'problemCategory', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByProblemCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'problemCategory', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionVoicePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoicePath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionVoicePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoicePath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionVoiceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoiceUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlRejectionVoiceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoiceUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatedAt', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatedAt', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationType', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationType', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidatorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatorId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTlValidatorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatorId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoicePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voicePath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoicePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voicePath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoiceStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoiceStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoiceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> sortByVoiceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceUrl', Sort.desc);
    });
  }
}

extension ReportQuerySortThenBy on QueryBuilder<Report, Report, QSortThenBy> {
  QueryBuilder<Report, Report, QAfterSortBy> thenByDbStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dbStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByDbStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dbStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsDbSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDbSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsDbSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDbSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsFullySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFullySynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsFullySyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFullySynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsPhotoSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPhotoSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsPhotoSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPhotoSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetryable', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsRetryableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetryable', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsVoiceSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isVoiceSynced', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByIsVoiceSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isVoiceSynced', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByMobileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByMobileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mobileId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByOwnerStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByOwnerStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByOwnerStatusAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatusAt', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByOwnerStatusAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerStatusAt', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByProblemCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'problemCategory', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByProblemCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'problemCategory', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionVoicePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoicePath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionVoicePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoicePath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionVoiceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoiceUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlRejectionVoiceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlRejectionVoiceUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatedAt', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatedAt', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationPhotoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoPath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationPhotoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoPath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationPhotoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationPhotoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationPhotoUrl', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationType', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidationType', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidatorId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatorId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTlValidatorIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tlValidatorId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoicePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voicePath', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoicePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voicePath', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoiceStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceStatus', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoiceStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceStatus', Sort.desc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoiceUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceUrl', Sort.asc);
    });
  }

  QueryBuilder<Report, Report, QAfterSortBy> thenByVoiceUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceUrl', Sort.desc);
    });
  }
}

extension ReportQueryWhereDistinct on QueryBuilder<Report, Report, QDistinct> {
  QueryBuilder<Report, Report, QDistinct> distinctByDbStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dbStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsDbSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDbSynced');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsFullySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFullySynced');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsPhotoSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPhotoSynced');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsRetryable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRetryable');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByIsVoiceSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isVoiceSynced');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lat');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lng');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByMobileId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mobileId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByOwnerStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByOwnerStatusAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerStatusAt');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByPhotoPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByPhotoStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByPhotoUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByProblemCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'problemCategory',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctBySupabaseId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'supabaseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlRejectionPhotoPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlRejectionPhotoPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlRejectionPhotoUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlRejectionPhotoUrl',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlRejectionVoicePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlRejectionVoicePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlRejectionVoiceUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlRejectionVoiceUrl',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tlValidatedAt');
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlValidationPhotoPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlValidationPhotoPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlValidationPhotoUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlValidationPhotoUrl',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlValidationType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlValidationType',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByTlValidatorId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'tlValidatorId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByUserId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByVoicePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'voicePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByVoiceStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'voiceStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Report, Report, QDistinct> distinctByVoiceUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'voiceUrl', caseSensitive: caseSensitive);
    });
  }
}

extension ReportQueryProperty on QueryBuilder<Report, Report, QQueryProperty> {
  QueryBuilder<Report, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> dbStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dbStatus');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isDbSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDbSynced');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isFullySyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFullySynced');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isPhotoSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPhotoSynced');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isRetryableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRetryable');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<Report, bool, QQueryOperations> isVoiceSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isVoiceSynced');
    });
  }

  QueryBuilder<Report, double, QQueryOperations> latProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lat');
    });
  }

  QueryBuilder<Report, double, QQueryOperations> lngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lng');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> mobileIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mobileId');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> ownerStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerStatus');
    });
  }

  QueryBuilder<Report, DateTime?, QQueryOperations> ownerStatusAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerStatusAt');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> photoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoPath');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> photoStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoStatus');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> photoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoUrl');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> problemCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'problemCategory');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> supabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supabaseId');
    });
  }

  QueryBuilder<Report, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<Report, String, QQueryOperations>
  tlRejectionPhotoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlRejectionPhotoPath');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> tlRejectionPhotoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlRejectionPhotoUrl');
    });
  }

  QueryBuilder<Report, String, QQueryOperations>
  tlRejectionVoicePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlRejectionVoicePath');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> tlRejectionVoiceUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlRejectionVoiceUrl');
    });
  }

  QueryBuilder<Report, DateTime?, QQueryOperations> tlValidatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlValidatedAt');
    });
  }

  QueryBuilder<Report, String, QQueryOperations>
  tlValidationPhotoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlValidationPhotoPath');
    });
  }

  QueryBuilder<Report, String, QQueryOperations>
  tlValidationPhotoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlValidationPhotoUrl');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> tlValidationTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlValidationType');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> tlValidatorIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tlValidatorId');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> voicePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'voicePath');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> voiceStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'voiceStatus');
    });
  }

  QueryBuilder<Report, String, QQueryOperations> voiceUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'voiceUrl');
    });
  }
}
