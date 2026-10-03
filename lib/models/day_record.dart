/// 经量档位。
enum FlowLevel { light, medium, heavy }

/// 痛经档位（`null` 表示「无」）。
enum CrampLevel { mild, moderate, severe }

/// 按天的记录：经量 / 痛经 / 备注。
class DayRecord {
  const DayRecord({required this.date, this.flow, this.cramps, this.note});

  final String date; // 'yyyy-MM-dd'（主键）
  final FlowLevel? flow;
  final CrampLevel? cramps;
  final String? note;

  /// 是否有可展示的症状记录（经量/痛经/非空备注）。
  bool get hasSymptom =>
      flow != null || cramps != null || (note != null && note!.isNotEmpty);

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'flow': flow?.name,
      'cramps': cramps?.name,
      'note': note,
    };
  }

  factory DayRecord.fromMap(Map<String, Object?> map) {
    return DayRecord(
      date: map['date'] as String,
      flow: _flowFromName(map['flow'] as String?),
      cramps: _crampFromName(map['cramps'] as String?),
      note: map['note'] as String?,
    );
  }

  static FlowLevel? _flowFromName(String? name) {
    if (name == null) return null;
    for (final e in FlowLevel.values) {
      if (e.name == name) return e;
    }
    return null;
  }

  static CrampLevel? _crampFromName(String? name) {
    if (name == null) return null;
    for (final e in CrampLevel.values) {
      if (e.name == name) return e;
    }
    return null;
  }
}
