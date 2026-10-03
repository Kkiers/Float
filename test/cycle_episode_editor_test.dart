import 'package:flutter_test/flutter_test.dart';
import 'package:float/models/period_episode.dart';
import 'package:float/services/cycle_episode_editor.dart';

DateTime d(int year, int month, int day) => DateTime(year, month, day);

void main() {
  group('CycleEpisodeEditor.isPeriodDay', () {
    test('落在闭合 episode 内', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      expect(
          CycleEpisodeEditor.isPeriodDay(eps, d(2026, 10, 3),
              today: d(2026, 10, 6)),
          isTrue);
      expect(
          CycleEpisodeEditor.isPeriodDay(eps, d(2026, 9, 30),
              today: d(2026, 10, 6)),
          isFalse);
    });

    test('open episode 覆盖 start..today', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1))];
      expect(
          CycleEpisodeEditor.isPeriodDay(eps, d(2026, 10, 3),
              today: d(2026, 10, 5)),
          isTrue);
      expect(
          CycleEpisodeEditor.isPeriodDay(eps, d(2026, 10, 5),
              today: d(2026, 10, 5)),
          isTrue);
      expect(
          CycleEpisodeEditor.isPeriodDay(eps, d(2026, 10, 6),
              today: d(2026, 10, 5)),
          isFalse);
    });
  });

  group('setPeriodDay on=true', () {
    test('空列表标记单日 → 1 日 episode', () {
      final r = CycleEpisodeEditor.setPeriodDay(const [], d(2026, 10, 3), true,
          today: d(2026, 10, 5));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 3));
      expect(r.first.endDate, d(2026, 10, 3));
    });

    test('向后延展（end==date-1）', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 3))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 4), true,
          today: d(2026, 10, 6));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 1));
      expect(r.first.endDate, d(2026, 10, 4));
    });

    test('向前延展（start==date+1）', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 4), endDate: d(2026, 10, 6))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 3), true,
          today: d(2026, 10, 10));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 3));
      expect(r.first.endDate, d(2026, 10, 6));
    });

    test('标记今天 → 进行中（open）', () {
      final r = CycleEpisodeEditor.setPeriodDay(const [], d(2026, 10, 5), true,
          today: d(2026, 10, 5));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 5));
      expect(r.first.isOngoing, isTrue);
    });

    test('补记今天补齐相邻段 → 进行中（open）', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 3), endDate: d(2026, 10, 4))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 5), true,
          today: d(2026, 10, 5));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 3));
      expect(r.first.isOngoing, isTrue);
    });

    test('桥接两个相邻 episode（中间日合并为一条）', () {
      final eps = [
        PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 3)),
        PeriodEpisode(startDate: d(2026, 10, 5), endDate: d(2026, 10, 7)),
      ];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 4), true,
          today: d(2026, 10, 8));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 1));
      expect(r.first.endDate, d(2026, 10, 7));
    });

    test('幂等：已是周期日再 on 无变化', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 3), true,
          today: d(2026, 10, 6));
      expect(r, same(eps));
    });
  });

  group('setPeriodDay on=false', () {
    test('取消段首 → start 前移', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 1), false,
          today: d(2026, 10, 6));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 2));
      expect(r.first.endDate, d(2026, 10, 5));
    });

    test('取消段尾 → end 前移', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 5), false,
          today: d(2026, 10, 6));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 1));
      expect(r.first.endDate, d(2026, 10, 4));
    });

    test('取消中间 → 拆成两段', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 3), false,
          today: d(2026, 10, 6));
      expect(r.length, 2);
      expect(r[0].startDate, d(2026, 10, 1));
      expect(r[0].endDate, d(2026, 10, 2));
      expect(r[1].startDate, d(2026, 10, 4));
      expect(r[1].endDate, d(2026, 10, 5));
    });

    test('取消单日 episode → 删除', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 3), endDate: d(2026, 10, 3))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 3), false,
          today: d(2026, 10, 6));
      expect(r, isEmpty);
    });

    test('幂等：非周期日再 off 无变化', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 8), false,
          today: d(2026, 10, 9));
      expect(r, same(eps));
    });
  });

  group('open episode 语义保持', () {
    test('补记后若最后一条覆盖今天 → 恢复 open 态', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1))]; // open，today=5
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 2), false,
          today: d(2026, 10, 5));
      // 去掉第 2 天：open 覆盖 [1..5] → [1,1]+[3..5]，恢复 open → [3,null]
      expect(r.length, 2);
      expect(r.last.isOngoing, isTrue);
      expect(r.last.startDate, d(2026, 10, 3));
    });

    test('补记后不再覆盖今天 → 保持闭合', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1))]; // open，today=5
      final r = CycleEpisodeEditor.setPeriodDay(eps, d(2026, 10, 5), false,
          today: d(2026, 10, 5));
      expect(r.length, 1);
      expect(r.first.isOngoing, isFalse);
      expect(r.first.endDate, d(2026, 10, 4));
    });
  });

  group('CycleEpisodeEditor.setPeriodRange', () {
    test('空列表整段标记 → 合并为一条', () {
      final r = CycleEpisodeEditor.setPeriodRange(
        const [], d(2026, 10, 3), d(2026, 10, 7), true, today: d(2026, 10, 10));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 3));
      expect(r.first.endDate, d(2026, 10, 7));
    });

    test('紧邻已有段的整段 → 向后延展', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 2))];
      final r = CycleEpisodeEditor.setPeriodRange(
        eps, d(2026, 10, 3), d(2026, 10, 5), true, today: d(2026, 10, 10));
      expect(r.length, 1);
      expect(r.first.startDate, d(2026, 10, 1));
      expect(r.first.endDate, d(2026, 10, 5));
    });

    test('off 整段 → 清空覆盖的周期日', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 7))];
      final r = CycleEpisodeEditor.setPeriodRange(
        eps, d(2026, 10, 3), d(2026, 10, 5), false, today: d(2026, 10, 10));
      expect(r.length, 2);
      expect(r[0].startDate, d(2026, 10, 1));
      expect(r[0].endDate, d(2026, 10, 2));
      expect(r[1].startDate, d(2026, 10, 6));
      expect(r[1].endDate, d(2026, 10, 7));
    });
  });

  group('CycleEpisodeEditor.periodLengthOf', () {
    test('闭合段内 → 返回段长', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      expect(CycleEpisodeEditor.periodLengthOf(eps, d(2026, 10, 3), today: d(2026, 10, 6)), 5);
    });

    test('open 段 → 按 start..today 计', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1))];
      expect(CycleEpisodeEditor.periodLengthOf(eps, d(2026, 10, 3), today: d(2026, 10, 5)), 5);
    });

    test('不在任何段 → null', () {
      final eps = [PeriodEpisode(startDate: d(2026, 10, 1), endDate: d(2026, 10, 5))];
      expect(CycleEpisodeEditor.periodLengthOf(eps, d(2026, 10, 8), today: d(2026, 10, 9)), isNull);
    });
  });
}
