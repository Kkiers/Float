import 'package:flutter_test/flutter_test.dart';
import 'package:float/models/cycle_settings.dart';
import 'package:float/models/period_episode.dart';
import 'package:float/services/cycle_predictor.dart';

void main() {
  final predictor = CyclePredictor();
  final today = DateTime(2026, 10, 3);
  const settings = CycleSettings();

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('CyclePredictor', () {
    test('无记录 → 空预测', () {
      final p = predictor.predict(
        episodes: const [],
        settings: settings,
        today: today,
      );
      expect(p.nextPeriodStart, isNull);
      expect(p.hasSufficientData, isFalse);
      expect(p.isCurrentlyMenstruating, isFalse);
      expect(p.isOverdue, isFalse);
    });

    test('单条记录 → 用典型周期回退预测', () {
      final episodes = [
        PeriodEpisode(startDate: d(2026, 9, 5), endDate: d(2026, 9, 9)),
      ];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      expect(p.hasSufficientData, isFalse);
      // 9/5 + 28 = 10/3
      expect(p.nextPeriodStart, d(2026, 10, 3));
      expect(p.daysUntilNext, 0);
    });

    test('多条记录 → 真实平均周期', () {
      final episodes = [
        PeriodEpisode(startDate: d(2026, 8, 8), endDate: d(2026, 8, 12)),
        PeriodEpisode(startDate: d(2026, 9, 5), endDate: d(2026, 9, 9)),
      ];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      expect(p.hasSufficientData, isTrue);
      // 8/8 -> 9/5 = 28 天
      expect(p.averageCycleLength, 28);
      expect(p.nextPeriodStart, d(2026, 10, 3));
      expect(p.daysUntilNext, 0);
    });

    test('逾期：记录延迟天数并前滚', () {
      final episodes = [
        PeriodEpisode(startDate: d(2026, 7, 4), endDate: d(2026, 7, 8)),
        PeriodEpisode(startDate: d(2026, 8, 1), endDate: d(2026, 8, 5)),
      ];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      // avgCycle = 28；baseNext = 8/1 + 28 = 8/29（已过 35 天）
      expect(p.isOverdue, isTrue);
      expect(p.overdueDays, 35);
      // 前滚到 >= today：10/24
      expect(p.nextPeriodStart, d(2026, 10, 24));
      expect(p.daysUntilNext, 21);
    });

    test('进行中的经期被标记', () {
      final episodes = [PeriodEpisode(startDate: d(2026, 10, 1))];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      expect(p.isCurrentlyMenstruating, isTrue);
    });

    test('平均经期来自闭合记录', () {
      final episodes = [
        PeriodEpisode(startDate: d(2026, 8, 1), endDate: d(2026, 8, 6)), // 6 天
        PeriodEpisode(startDate: d(2026, 9, 1), endDate: d(2026, 9, 4)), // 4 天
      ];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      expect(p.averagePeriodLength, 5); // (6+4)/2
    });

    test('预测窗口含首尾', () {
      final episodes = [
        PeriodEpisode(startDate: d(2026, 9, 5), endDate: d(2026, 9, 9)),
      ];
      final p = predictor.predict(
        episodes: episodes,
        settings: settings,
        today: today,
      );
      expect(p.nextPeriodStart, d(2026, 10, 3));
      expect(p.predictedEnd, d(2026, 10, 7)); // 5 天
      expect(p.predictedWindowDays.length, 5);
      expect(p.predictedWindowDays.first, d(2026, 10, 3));
      expect(p.predictedWindowDays.last, d(2026, 10, 7));
    });
  });

  group('CyclePredictor.robustCycles', () {
    test('规律周期全部保留', () {
      final starts = [
        d(2026, 1, 1), d(2026, 1, 29), d(2026, 2, 26), d(2026, 3, 26),
      ];
      expect(
        CyclePredictor.robustCycles(starts).map((c) => c.days),
        [28, 28, 28],
      );
    });

    test('漏记一个月（约 2 倍间隔）被剔除', () {
      final starts = [
        d(2026, 1, 1), d(2026, 1, 29), d(2026, 2, 26),
        d(2026, 4, 23), d(2026, 5, 21), // 3 月漏记：2/26 → 4/23 = 56 天
      ];
      final cycles = CyclePredictor.robustCycles(starts);
      expect(cycles.map((c) => c.days), [28, 28, 28]);
      expect(cycles.any((c) => c.days >= 56), isFalse);
    });

    test('漏记月份使间隔略超典型周期（35→45 天）也被剔除', () {
      // 真实数据：7/15 → 8/19 = 35 天，8/19 → 10/3 = 45 天（漏记 9 月）。
      final starts = [d(2026, 7, 15), d(2026, 8, 19), d(2026, 10, 3)];
      final cycles = CyclePredictor.robustCycles(starts, typical: 28);
      expect(cycles.map((c) => c.days), [35]);
    });

    test('不足两条开始日 → 空', () {
      expect(CyclePredictor.robustCycles(const []), isEmpty);
      expect(CyclePredictor.robustCycles([d(2026, 1, 1)]), isEmpty);
    });
  });
}
