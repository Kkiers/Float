import 'package:flutter_test/flutter_test.dart';
import 'package:float/models/day_record.dart';

void main() {
  group('DayRecord', () {
    test('toMap/fromMap 往返', () {
      final r = DayRecord(
        date: '2026-10-03',
        flow: FlowLevel.medium,
        cramps: CrampLevel.mild,
        note: 'ok',
      );
      final back = DayRecord.fromMap(r.toMap());
      expect(back.date, '2026-10-03');
      expect(back.flow, FlowLevel.medium);
      expect(back.cramps, CrampLevel.mild);
      expect(back.note, 'ok');
      expect(back.hasSymptom, isTrue);
    });

    test('空记录无症状', () {
      final r = DayRecord(date: '2026-10-03');
      expect(r.hasSymptom, isFalse);
    });

    test('无痛经为 null', () {
      final r = DayRecord(date: '2026-10-03', cramps: null);
      expect(r.cramps, isNull);
      expect(r.hasSymptom, isFalse);
    });

    test('仅备注也算症状', () {
      final r = DayRecord(date: '2026-10-03', note: ' 腹痛  ');
      expect(r.hasSymptom, isTrue);
    });

    test('未知枚举名回退为 null', () {
      final back = DayRecord.fromMap({
        'date': '2026-10-03',
        'flow': 'bogus',
        'cramps': 'bogus',
        'note': null,
      });
      expect(back.flow, isNull);
      expect(back.cramps, isNull);
    });
  });
}
