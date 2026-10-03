import 'package:intl/intl.dart';

/// 周期模块的日期工具：统一用本地日历日期字符串 `yyyy-MM-dd` 表示「某一天」。
///
/// 经期天的身份是日历概念，不该用 epoch 毫秒（跨时区/DST 会把日期漂移）；
/// `yyyy-MM-dd` 字符串保证「是否同一天」精确相等，且字典序 = 时间序。
class CycleDates {
  CycleDates._();

  static final DateFormat _keyFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _monthDayFmt = DateFormat('M月d日');
  static final DateFormat _yearMonthFmt = DateFormat('yyyy年M月');
  static final DateFormat _monthFmt = DateFormat('M月');

  static const List<String> _weekdayShort = ['一', '二', '三', '四', '五', '六', '日'];

  /// 本地零点（去掉时分秒），保证日期比较/运算一致。
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 日期 → `yyyy-MM-dd`。
  static String dateKey(DateTime d) => _keyFmt.format(dateOnly(d));

  /// `yyyy-MM-dd` → 本地零点 DateTime。
  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 整天差：`b - a`（以 UTC 重建，规避 DST/偏移漂移，测试确定性）。
  static int daysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  /// 加/减天数，返回本地零点 DateTime（自动跨月/年归一化）。
  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// 星期几的短标签（`weekday`: 1=周一 … 7=周日）。
  static String weekdayShort(int weekday) => _weekdayShort[weekday - 1];

  static String formatMonthDay(DateTime d) => _monthDayFmt.format(dateOnly(d));

  static String formatYearMonth(DateTime d) => _yearMonthFmt.format(dateOnly(d));

  static String formatMonth(DateTime d) => _monthFmt.format(dateOnly(d));
}
