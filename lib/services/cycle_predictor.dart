import '../models/cycle_settings.dart';
import '../models/period_episode.dart';
import 'cycle_dates.dart';

/// 一次预测的结果。
class CyclePrediction {
  const CyclePrediction({
    this.nextPeriodStart,
    this.predictedEnd,
    this.expectedStart,
    this.predictedWindowDays = const [],
    required this.averageCycleLength,
    required this.averagePeriodLength,
    this.daysUntilNext,
    this.overdueDays = 0,
    required this.hasSufficientData,
    required this.isCurrentlyMenstruating,
  });

  /// 下一次经期开始日（始终 >= 今天，已做逾期前滚）；无锚点时为 null。
  final DateTime? nextPeriodStart;

  /// 预测结束日 = nextPeriodStart + 平均经期 - 1。
  final DateTime? predictedEnd;

  /// 原始预计开始日（未做逾期前滚；逾期时早于今天，用于「原预计…已过」）。
  final DateTime? expectedStart;

  /// 预测窗口内的每一天（含首尾），供日历/时间线画「空心玫瑰」。
  final List<DateTime> predictedWindowDays;

  final int averageCycleLength;
  final int averagePeriodLength;

  /// 距下次经期天数（>= 0）。
  final int? daysUntilNext;

  /// 逾期天数（> 0 表示经期已晚；否则 0）。
  final int overdueDays;

  /// 是否已有 >= 2 条经期开始记录（数据足以算真实平均周期）。
  final bool hasSufficientData;

  /// 当前是否处于经期中（存在进行中的 episode 且今天在其范围内）。
  final bool isCurrentlyMenstruating;

  bool get isOverdue => overdueDays > 0;
}

/// 一条稳健周期：天数 + 这次周期对应的「后一次开始日」（图表横轴标签用）。
class RobustCycle {
  const RobustCycle({required this.days, required this.endStart});

  final int days;
  final DateTime endStart;
}

/// 纯 Dart 预测引擎，无 I/O、无 Widget，可独立单测。
///
/// 混合模式：有 >= 2 条开始记录时用真实平均周期；否则回退到
/// `typicalCycleLength`（默认 28），所以第一条记录就能出预测。
class CyclePredictor {
  CyclePrediction predict({
    required List<PeriodEpisode> episodes,
    required CycleSettings settings,
    required DateTime today,
  }) {
    final t = CycleDates.dateOnly(today);

    // 去重升序的开始日期
    final seen = <String>{};
    final starts = <DateTime>[];
    for (final e in episodes) {
      final k = CycleDates.dateKey(e.startDate);
      if (seen.add(k)) starts.add(CycleDates.dateOnly(e.startDate));
    }
    starts.sort((a, b) => a.compareTo(b));

    final avgCycle = _averageCycle(starts, settings);
    final avgPeriod = _averagePeriod(episodes, settings, t);

    if (starts.isEmpty) {
      return CyclePrediction(
        averageCycleLength: avgCycle,
        averagePeriodLength: avgPeriod,
        hasSufficientData: false,
        isCurrentlyMenstruating: false,
      );
    }

    final lastStart = starts.last;
    final baseNext = CycleDates.addDays(lastStart, avgCycle);

    // 逾期：基准预测日已过 → 记录晚了多少天。
    final baseGap = CycleDates.daysBetween(baseNext, t);
    final overdueDays = baseGap > 0 ? baseGap : 0;

    // 前滚：让「下一次」始终落在今天或未来（供画预测窗口）。
    var next = baseNext;
    while (CycleDates.daysBetween(next, t) > 0) {
      next = CycleDates.addDays(next, avgCycle);
    }

    final predictedEnd = CycleDates.addDays(next, avgPeriod - 1);
    final window = <DateTime>[];
    var d = next;
    while (!d.isAfter(predictedEnd)) {
      window.add(d);
      d = CycleDates.addDays(d, 1);
    }

    final daysUntilNext = CycleDates.daysBetween(t, next);
    final isCurrentlyMenstruating = _isMenstruating(episodes, t);

    return CyclePrediction(
      nextPeriodStart: next,
      predictedEnd: predictedEnd,
      expectedStart: baseNext,
      predictedWindowDays: window,
      averageCycleLength: avgCycle,
      averagePeriodLength: avgPeriod,
      daysUntilNext: daysUntilNext < 0 ? 0 : daysUntilNext,
      overdueDays: overdueDays,
      hasSufficientData: starts.length >= 2,
      isCurrentlyMenstruating: isCurrentlyMenstruating,
    );
  }

  /// 稳健周期长度：剔除「漏记月份」造成的异常大间隔。
  ///
  /// 漏记只会让相邻两次开始日的间隔**变长**（约 1.5~2 倍典型周期），不会变短。
  /// 以「典型周期」与「最短间隔」中的较小者为锚，把 `>= 1.5 × 锚` 的间隔判为漏记并剔除；
  /// 若典型周期缺失（0），退回到「最短间隔」作为锚。
  static List<RobustCycle> robustCycles(List<DateTime> starts, {int typical = 28}) {
    if (starts.length < 2) return const [];
    final raw = <RobustCycle>[
      for (var i = 1; i < starts.length; i++)
        RobustCycle(
          days: CycleDates.daysBetween(starts[i - 1], starts[i]),
          endStart: starts[i],
        ),
    ];
    final minDays = raw.map((c) => c.days).reduce((a, b) => a < b ? a : b);
    // 取典型周期与最短间隔的较小者：既避免「典型设得过大」时漏记月份漏网，
    // 也避免真实周期比典型更长时被误删。
    final anchor = typical > 0 ? (typical < minDays ? typical : minDays) : minDays;
    final threshold = (anchor * 1.5).round();
    return raw.where((c) => c.days < threshold).toList();
  }

  int _averageCycle(List<DateTime> starts, CycleSettings settings) {
    final cycles = robustCycles(starts, typical: settings.typicalCycleLength);
    if (cycles.isEmpty) return settings.typicalCycleLength;
    final sum = cycles.fold<int>(0, (a, c) => a + c.days);
    final mean = (sum / cycles.length).round();
    return mean.clamp(15, 60);
  }

  int _averagePeriod(
      List<PeriodEpisode> episodes, CycleSettings settings, DateTime today) {
    final closed = episodes.where((e) => !e.isOngoing).toList();
    if (closed.isEmpty) return settings.typicalPeriodLength;
    var sum = 0;
    for (final e in closed) {
      sum += e.periodLengthDays(today);
    }
    final mean = (sum / closed.length).round();
    return mean.clamp(1, 14);
  }

  bool _isMenstruating(List<PeriodEpisode> episodes, DateTime today) {
    for (final e in episodes) {
      // 进行中的 episode：今天在其开始日之后（含当天）即视为仍在经期中。
      if (e.isOngoing && !e.startDate.isAfter(today)) return true;
    }
    return false;
  }
}
