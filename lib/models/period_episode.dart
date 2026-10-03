import '../services/cycle_dates.dart';

/// 一次经期事件：开始日 + （可选）结束日。`endDate == null` 表示进行中。
class PeriodEpisode {
  const PeriodEpisode({this.id, required this.startDate, this.endDate});

  final int? id;
  final DateTime startDate; // 本地零点
  final DateTime? endDate; // null = 进行中

  bool get isOngoing => endDate == null;

  /// 经期长度（含首尾）。进行中的经期截止到今天（不把未来算进去）。
  int periodLengthDays(DateTime today) {
    final end = endDate ?? today;
    final len = CycleDates.daysBetween(startDate, end) + 1;
    return len < 1 ? 1 : len;
  }

  PeriodEpisode copyWith({int? id, DateTime? startDate, DateTime? endDate}) {
    return PeriodEpisode(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'start_date': CycleDates.dateKey(startDate),
      'end_date': endDate == null ? null : CycleDates.dateKey(endDate!),
    };
  }

  factory PeriodEpisode.fromMap(Map<String, Object?> map) {
    return PeriodEpisode(
      id: map['id'] as int?,
      startDate: CycleDates.parseDateKey(map['start_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : CycleDates.parseDateKey(map['end_date'] as String),
    );
  }
}
