import 'package:flutter/material.dart';

import '../../models/cycle_settings.dart';
import '../../models/period_episode.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_predictor.dart';
import '../../theme/app_theme.dart';

/// 统计页：平均周期/经期、最短/最长、最近 6 个周期柱状图。
class CycleStatsTab extends StatelessWidget {
  const CycleStatsTab({
    super.key,
    required this.episodes,
    required this.prediction,
    required this.settings,
  });

  final List<PeriodEpisode> episodes;
  final CyclePrediction prediction;
  final CycleSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starts = _starts();
    if (starts.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '记录至少两次经期后显示统计',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    final allCycles =
        CyclePredictor.robustCycles(starts, typical: settings.typicalCycleLength);
    // 所有间隔都被判为「漏记」时（例如两次记录隔了约 2 倍典型周期），
    // robustCycles 返回空，避免对空列表 reduce 崩溃。
    if (allCycles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '记录的间隔较长（可能漏记了月份），暂无法统计',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }
    final cycles = allCycles.length > 6
        ? allCycles.sublist(allCycles.length - 6)
        : allCycles;
    final lengths = cycles.map((c) => c.days).toList();
    final labels = cycles.map((c) => CycleDates.formatMonth(c.endStart)).toList();

    final minCycle = lengths.reduce((a, b) => a < b ? a : b);
    final maxCycle = lengths.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '平均周期',
                value: '${prediction.averageCycleLength}',
                unit: '天',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '平均经期',
                value: '${prediction.averagePeriodLength}',
                unit: '天',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(label: '最短周期', value: '$minCycle', unit: '天'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(label: '最长周期', value: '$maxCycle', unit: '天'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '周期趋势',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.cycleTextNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _BarChart(cycleLengths: lengths, monthLabels: labels),
      ],
    );
  }

  List<DateTime> _starts() {
    final seen = <String>{};
    final out = <DateTime>[];
    for (final e in episodes) {
      final k = CycleDates.dateKey(e.startDate);
      if (seen.add(k)) out.add(CycleDates.dateOnly(e.startDate));
    }
    out.sort((a, b) => a.compareTo(b));
    return out;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.cycleTextNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(unit,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.cycleLengths, required this.monthLabels});

  final List<int> cycleLengths;
  final List<String> monthLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxLen = cycleLengths.fold<int>(1, (a, b) => a > b ? a : b);
    const chartHeight = 150.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < cycleLengths.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cycleLengths[i]}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cycleTextNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: chartHeight * cycleLengths[i] / maxLen,
                    decoration: BoxDecoration(
                      color: i == cycleLengths.length - 1
                          ? AppTheme.cycleRose
                          : AppTheme.cycleRoseFill,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    monthLabels[i],
                    style:
                        TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
