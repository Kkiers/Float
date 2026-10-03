import '../models/period_episode.dart';
import 'cycle_dates.dart';

/// 纯 Dart 的「经期事件编辑器」：把「某天有没有月经」翻译成 episode 列表的变更。
///
/// 无 IO、不修改传入列表，便于单测。数据模型不变（仍是 `period_episodes`），
/// 只是提供按天开关的入口来增/删/延展/拆分 episode。
class CycleEpisodeEditor {
  CycleEpisodeEditor._();

  /// `date` 是否落在某个 episode 内（进行中的 open episode 视为覆盖 `start..today`）。
  static bool isPeriodDay(
    List<PeriodEpisode> episodes,
    DateTime date, {
    required DateTime today,
  }) {
    final d = CycleDates.dateOnly(date);
    for (final e in episodes) {
      final start = CycleDates.dateOnly(e.startDate);
      final end = CycleDates.dateOnly(e.endDate ?? today);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  /// 把 `date` 的「经期状态」设为 `on`，返回新的（已排序、规范化）episode 列表。
  ///
  /// - 幂等：状态未变时原样返回。
  /// - 若结果里最后一条 episode 覆盖到今天（end == today），会记为「进行中」（open），
  ///   保证「今天有月经」时主页「结束了」按钮与「经期中」状态正确。
  static List<PeriodEpisode> setPeriodDay(
    List<PeriodEpisode> episodes,
    DateTime date,
    bool on, {
    required DateTime today,
  }) {
    final d = CycleDates.dateOnly(date);
    final alreadyOn = isPeriodDay(episodes, d, today: today);

    if (on) {
      if (alreadyOn) return episodes;
      return _markOn(episodes, d, today);
    } else {
      if (!alreadyOn) return episodes;
      return _markOff(episodes, d, today);
    }
  }

  /// 把 `[start, end]`（含首尾）整段的「经期状态」设为 `on`。
  ///
  /// 复用 [setPeriodDay] 逐天标记，相邻天自动合并为一段，供「补记整段经期」一次填多天。
  static List<PeriodEpisode> setPeriodRange(
    List<PeriodEpisode> episodes,
    DateTime start,
    DateTime end,
    bool on, {
    required DateTime today,
  }) {
    var result = episodes;
    var d = CycleDates.dateOnly(start);
    final last = CycleDates.dateOnly(end);
    while (!d.isAfter(last)) {
      result = setPeriodDay(result, d, on, today: today);
      d = CycleDates.addDays(d, 1);
    }
    return result;
  }

  /// 该日所在 episode 的长度（含首尾）；不在任何经期内返回 null。
  static int? periodLengthOf(
    List<PeriodEpisode> episodes,
    DateTime date, {
    required DateTime today,
  }) {
    final d = CycleDates.dateOnly(date);
    for (final e in episodes) {
      final start = CycleDates.dateOnly(e.startDate);
      final end = CycleDates.dateOnly(e.endDate ?? today);
      if (!d.isBefore(start) && !d.isAfter(end)) {
        return CycleDates.daysBetween(start, end) + 1;
      }
    }
    return null;
  }

  /// 标记这天「有月经」：延展相邻 episode 或新建单日 episode。
  static List<PeriodEpisode> _markOn(
    List<PeriodEpisode> episodes,
    DateTime d,
    DateTime today,
  ) {
    final closed = _closedSorted(episodes, today);
    final yesterday = CycleDates.dateKey(CycleDates.addDays(d, -1));
    final tomorrow = CycleDates.dateKey(CycleDates.addDays(d, 1));

    int? prevIdx;
    int? nextIdx;
    for (var i = 0; i < closed.length; i++) {
      final e = closed[i];
      if (CycleDates.dateKey(e.endDate!) == yesterday) prevIdx = i;
      if (CycleDates.dateKey(e.startDate) == tomorrow) nextIdx = i;
    }

    // 无相邻：新建单日 episode。
    if (prevIdx == null && nextIdx == null) {
      final r = [...closed, PeriodEpisode(startDate: d, endDate: d)];
      return _normalize(r, today);
    }

    // 前后都有：合并（prev 吸收 next，中间这天补齐）。
    if (prevIdx != null && nextIdx != null) {
      final mergedEnd = closed[nextIdx].endDate;
      final r = <PeriodEpisode>[];
      for (var i = 0; i < closed.length; i++) {
        if (i == prevIdx) {
          r.add(closed[i].copyWith(endDate: mergedEnd));
        } else if (i == nextIdx) {
          // 跳过，已并入 prev
        } else {
          r.add(closed[i]);
        }
      }
      return _normalize(r, today);
    }

    // 只有一侧：延展。
    final r = <PeriodEpisode>[];
    for (var i = 0; i < closed.length; i++) {
      if (i == prevIdx) {
        r.add(closed[i].copyWith(endDate: d));
      } else if (i == nextIdx) {
        r.add(closed[i].copyWith(startDate: d));
      } else {
        r.add(closed[i]);
      }
    }
    return _normalize(r, today);
  }

  /// 标记这天「没月经」：删除 / 收缩 / 拆分包含它的 episode。
  static List<PeriodEpisode> _markOff(
    List<PeriodEpisode> episodes,
    DateTime d,
    DateTime today,
  ) {
    final closed = _closedSorted(episodes, today);
    final r = <PeriodEpisode>[];

    for (final e in closed) {
      final start = CycleDates.dateOnly(e.startDate);
      final end = CycleDates.dateOnly(e.endDate!);
      if (d.isBefore(start) || d.isAfter(end)) {
        r.add(e);
        continue;
      }

      final dk = CycleDates.dateKey(d);
      final sk = CycleDates.dateKey(start);
      final ek = CycleDates.dateKey(end);
      if (dk == sk && dk == ek) {
        // 单日 episode：整条删除。
      } else if (dk == sk) {
        r.add(e.copyWith(startDate: CycleDates.addDays(d, 1)));
      } else if (dk == ek) {
        r.add(e.copyWith(endDate: CycleDates.addDays(d, -1)));
      } else {
        // 中间：拆成两段。
        r.add(e.copyWith(endDate: CycleDates.addDays(d, -1)));
        r.add(PeriodEpisode(startDate: CycleDates.addDays(d, 1), endDate: end));
      }
    }

    return _normalize(r, today);
  }

  /// 把 open episode 视为闭合区间 `[start, today]`，并按开始日升序排序。
  static List<PeriodEpisode> _closedSorted(
    List<PeriodEpisode> episodes,
    DateTime today,
  ) {
    return episodes
        .map((e) => e.isOngoing ? e.copyWith(endDate: today) : e)
        .toList()
      ..sort(_byStart);
  }

  /// 排序；若最后一条 episode 覆盖到今天（end == today），记为进行中（endDate=null）。
  static List<PeriodEpisode> _normalize(List<PeriodEpisode> list, DateTime today) {
    final r = [...list]..sort(_byStart);
    if (r.isNotEmpty) {
      final last = r.last;
      if (CycleDates.dateKey(last.endDate!) == CycleDates.dateKey(today)) {
        r[r.length - 1] = PeriodEpisode(
          id: last.id,
          startDate: last.startDate,
          endDate: null,
        );
      }
    }
    return r;
  }

  static int _byStart(PeriodEpisode a, PeriodEpisode b) =>
      CycleDates.dateKey(a.startDate).compareTo(CycleDates.dateKey(b.startDate));
}
