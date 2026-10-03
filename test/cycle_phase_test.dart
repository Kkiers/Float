import 'package:flutter_test/flutter_test.dart';
import 'package:float/services/cycle_phase.dart';

DateTime d(int month, int day) => DateTime(2026, month, day);

void main() {
  // 上次经期开始 10-01，周期 28 天、经期 5 天。
  final lastStart = d(10, 1);

  CyclePhase resolve(DateTime today) => CyclePhaseResolver.resolve(
        lastStart: lastStart,
        averageCycleLength: 28,
        averagePeriodLength: 5,
        today: today,
      );

  group('CyclePhaseResolver', () {
    test('无上次经期 → unknown', () {
      expect(
        CyclePhaseResolver.resolve(
          lastStart: null,
          averageCycleLength: 28,
          averagePeriodLength: 5,
          today: d(10, 10),
        ),
        CyclePhase.unknown,
      );
    });

    test('月经期（第 1~5 天）', () {
      expect(resolve(d(10, 1)), CyclePhase.menstrual);
      expect(resolve(d(10, 5)), CyclePhase.menstrual);
    });

    test('卵泡期（经期后到排卵前）', () {
      expect(resolve(d(10, 6)), CyclePhase.follicular);
      expect(resolve(d(10, 12)), CyclePhase.follicular);
    });

    test('排卵期（排卵日前后各 1 天）', () {
      expect(resolve(d(10, 13)), CyclePhase.ovulation);
      expect(resolve(d(10, 15)), CyclePhase.ovulation);
    });

    test('黄体期（排卵后）', () {
      expect(resolve(d(10, 16)), CyclePhase.luteal);
      expect(resolve(d(10, 28)), CyclePhase.luteal);
    });

    test('逾期（超过周期长度）仍归入黄体期', () {
      expect(resolve(d(11, 1)), CyclePhase.luteal);
    });
  });
}
