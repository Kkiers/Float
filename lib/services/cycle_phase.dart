import 'cycle_dates.dart';

/// 月经周期阶段（按专业分期）。
enum CyclePhase { menstrual, follicular, ovulation, luteal, unknown }

/// 根据「上次经期开始日 + 平均周期/经期天数」推算今天处于哪个阶段。
///
/// 简化模型（周期日从上次经期开始日算作第 1 天）：
/// - 第 1 ~ 经期天数：月经期；
/// - 之后到排卵前 2 天：卵泡期；
/// - 排卵日（≈ 周期 − 14）前后各 1 天：排卵期；
/// - 排卵后：黄体期（逾期也归入黄体期）。
class CyclePhaseResolver {
  CyclePhaseResolver._();

  static CyclePhase resolve({
    required DateTime? lastStart,
    required int averageCycleLength,
    required int averagePeriodLength,
    required DateTime today,
  }) {
    if (lastStart == null) return CyclePhase.unknown;

    final day = CycleDates.daysBetween(lastStart, today) + 1;
    if (day < 1) return CyclePhase.unknown;

    final periodLen = averagePeriodLength < 1 ? 1 : averagePeriodLength;
    if (day <= periodLen) return CyclePhase.menstrual;

    final cycleLen = averageCycleLength < 15 ? 15 : averageCycleLength;
    var ovulationDay = cycleLen - 14;
    if (ovulationDay <= periodLen) ovulationDay = periodLen + 1;

    if (day < ovulationDay - 1) return CyclePhase.follicular;
    if (day <= ovulationDay + 1) return CyclePhase.ovulation;
    return CyclePhase.luteal;
  }
}
