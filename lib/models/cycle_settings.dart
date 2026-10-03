/// 周期相关设置（单行存储，主键固定为 1）。
class CycleSettings {
  const CycleSettings({
    this.typicalCycleLength = 28,
    this.typicalPeriodLength = 5,
    this.onboarded = false,
  });

  final int typicalCycleLength; // 典型周期天数（默认 28）
  final int typicalPeriodLength; // 典型经期天数（默认 5）
  final bool onboarded; // 是否已完成首次引导

  CycleSettings copyWith({
    int? typicalCycleLength,
    int? typicalPeriodLength,
    bool? onboarded,
  }) {
    return CycleSettings(
      typicalCycleLength: typicalCycleLength ?? this.typicalCycleLength,
      typicalPeriodLength: typicalPeriodLength ?? this.typicalPeriodLength,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'typical_cycle_length': typicalCycleLength,
      'typical_period_length': typicalPeriodLength,
      'onboarded': onboarded ? 1 : 0,
    };
  }

  factory CycleSettings.fromMap(Map<String, Object?> map) {
    return CycleSettings(
      typicalCycleLength: (map['typical_cycle_length'] as int?) ?? 28,
      typicalPeriodLength: (map['typical_period_length'] as int?) ?? 5,
      onboarded: ((map['onboarded'] as int?) ?? 0) == 1,
    );
  }
}
