import 'package:flutter_test/flutter_test.dart';
import 'package:float/models/period_episode.dart';

void main() {
  group('PeriodEpisode', () {
    test('toMap/fromMap 往返', () {
      final e = PeriodEpisode(
        id: 1,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
      );
      final back = PeriodEpisode.fromMap(e.toMap());
      expect(back.id, 1);
      expect(back.startDate, DateTime(2026, 10, 1));
      expect(back.endDate, DateTime(2026, 10, 5));
      expect(back.isOngoing, isFalse);
    });

    test('进行中 end_date 为 null', () {
      final e = PeriodEpisode(startDate: DateTime(2026, 10, 1));
      final map = e.toMap();
      expect(map['end_date'], isNull);
      expect(e.isOngoing, isTrue);

      final back = PeriodEpisode.fromMap(map);
      expect(back.endDate, isNull);
      expect(back.isOngoing, isTrue);
    });

    test('经期长度含首尾', () {
      final e = PeriodEpisode(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
      );
      expect(e.periodLengthDays(DateTime(2026, 10, 3)), 5);
    });

    test('进行中经期长度截止到今天', () {
      final e = PeriodEpisode(startDate: DateTime(2026, 10, 1));
      expect(e.periodLengthDays(DateTime(2026, 10, 4)), 4);
    });
  });
}
