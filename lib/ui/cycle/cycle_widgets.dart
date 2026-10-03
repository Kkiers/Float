import 'package:flutter/material.dart';

import '../../models/day_record.dart';
import '../../models/period_episode.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_predictor.dart';
import '../../theme/app_theme.dart';

/// 渲染时由 episode / 按天记录 / 预测 推导出的「天集合」。
///
/// 三个 `Set<String>`（键为 `yyyy-MM-dd`）被时间线、日历复用，
/// 保证同一逻辑下三处渲染一致。
class CycleDaySets {
  const CycleDaySets({
    required this.recorded,
    required this.predicted,
    required this.symptom,
  });

  /// 已记录经期日（实心玫瑰）。
  final Set<String> recorded;

  /// 预测经期日（空心玫瑰）。
  final Set<String> predicted;

  /// 有症状记录的非经期日（灰/紫点）。
  final Set<String> symptom;

  static const empty = CycleDaySets(
    recorded: <String>{},
    predicted: <String>{},
    symptom: <String>{},
  );

  static CycleDaySets from({
    required List<PeriodEpisode> episodes,
    required List<DayRecord> dayRecords,
    required CyclePrediction prediction,
    required DateTime today,
  }) {
    final recorded = <String>{};
    for (final e in episodes) {
      final last = e.endDate ?? today; // 进行中截止到今天
      var d = CycleDates.dateOnly(e.startDate);
      while (!d.isAfter(last)) {
        recorded.add(CycleDates.dateKey(d));
        d = CycleDates.addDays(d, 1);
      }
    }

    final predicted = <String>{};
    for (final d in prediction.predictedWindowDays) {
      final k = CycleDates.dateKey(d);
      if (!recorded.contains(k)) predicted.add(k);
    }

    final symptom = <String>{};
    for (final r in dayRecords) {
      if (r.hasSymptom && !recorded.contains(r.date)) {
        symptom.add(r.date);
      }
    }

    return CycleDaySets(
      recorded: recorded,
      predicted: predicted,
      symptom: symptom,
    );
  }
}

/// 圆点槽：实心玫瑰=记录 / 空心玫瑰=预测 / 彩色圆点=症状。
class DayMarkers extends StatelessWidget {
  const DayMarkers({
    super.key,
    required this.sets,
    required this.dateKey,
    required this.symptomColor,
  });

  final CycleDaySets sets;
  final String dateKey;
  final Color symptomColor;

  @override
  Widget build(BuildContext context) {
    final isRecorded = sets.recorded.contains(dateKey);
    final isPredicted = sets.predicted.contains(dateKey);
    final isSymptom = sets.symptom.contains(dateKey);

    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isRecorded) _dot(AppTheme.cycleRose, filled: true),
          if (isPredicted) _dot(AppTheme.cycleRose, filled: false),
          if (isSymptom) _dot(symptomColor, filled: true),
        ],
      ),
    );
  }

  Widget _dot(Color color, {required bool filled}) {
    return Container(
      width: 6.5,
      height: 6.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}
