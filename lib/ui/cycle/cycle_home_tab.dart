import 'package:flutter/material.dart';

import '../../models/cycle_settings.dart';
import '../../models/period_episode.dart';
import '../../services/analytics_service.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_phase.dart';
import '../../services/cycle_predictor.dart';
import '../../services/cycle_storage.dart';
import '../../theme/app_theme.dart';
import 'cycle_widgets.dart';
import 'day_detail_sheet.dart';

/// 主页：时间线 + 倒计时卡片 + 一键「月经来了/结束了」。
class CycleHomeTab extends StatefulWidget {
  const CycleHomeTab({
    super.key,
    required this.episodes,
    required this.settings,
    required this.prediction,
    required this.daySets,
    required this.today,
    required this.onDataChanged,
    required this.onSelectDate,
  });

  final List<PeriodEpisode> episodes;
  final CycleSettings settings;
  final CyclePrediction prediction;
  final CycleDaySets daySets;
  final DateTime today;
  final Future<void> Function() onDataChanged;
  final ValueChanged<DateTime?> onSelectDate;

  @override
  State<CycleHomeTab> createState() => _CycleHomeTabState();
}

class _CycleHomeTabState extends State<CycleHomeTab> {
  bool _busy = false;

  PeriodEpisode? get _openEpisode {
    for (final e in widget.episodes) {
      if (e.isOngoing) return e;
    }
    return null;
  }

  PeriodEpisode? get _lastClosed {
    PeriodEpisode? last;
    for (final e in widget.episodes) {
      if (!e.isOngoing) last = e;
    }
    return last;
  }

  /// 最近一次经期开始日（用于推算当前阶段）。
  DateTime? get _lastStart {
    DateTime? last;
    for (final e in widget.episodes) {
      if (last == null || e.startDate.isAfter(last)) last = e.startDate;
    }
    return last;
  }

  Future<void> _togglePeriod() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final open = _openEpisode;
      if (open == null) {
        await CycleStorage.instance
            .insertEpisode(PeriodEpisode(startDate: widget.today));
        AnalyticsService.instance.trackEvent('cycle_period_started',
            properties: {'date': CycleDates.dateKey(widget.today)});
      } else {
        await CycleStorage.instance
            .updateEpisode(open.copyWith(endDate: widget.today));
        AnalyticsService.instance.trackEvent('cycle_period_ended', properties: {
          'date': CycleDates.dateKey(widget.today),
          'length_days': open.periodLengthDays(widget.today),
        });
      }
      await widget.onDataChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 点时间线某天：打开「某天详情」弹层（补记 / 修正经期 + 症状）。
  Future<void> _openDay(DateTime date) async {
    final existing =
        await CycleStorage.instance.getDayRecord(CycleDates.dateKey(date));
    if (!mounted) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DayDetailSheet(
        date: date,
        existing: existing,
        episodes: widget.episodes,
        today: widget.today,
        typicalPeriodLength: widget.settings.typicalPeriodLength,
      ),
    );
    if (changed == true) {
      widget.onSelectDate(date);
      await widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = widget.episodes.isNotEmpty;
    final phase = CyclePhaseResolver.resolve(
      lastStart: _lastStart,
      averageCycleLength: widget.prediction.averageCycleLength,
      averagePeriodLength: widget.prediction.averagePeriodLength,
      today: widget.today,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _DateTimelineStrip(
          daySets: widget.daySets,
          today: widget.today,
          onTapDay: _openDay,
        ),
        const SizedBox(height: 16),
        if (phase != CyclePhase.unknown) ...[
          _CyclePhaseCard(phase: phase),
          const SizedBox(height: 16),
        ],
        _CycleInfoCard(
          prediction: widget.prediction,
          openEpisode: _openEpisode,
          lastClosed: _lastClosed,
          today: widget.today,
        ),
        const SizedBox(height: 20),
        _PeriodToggleButton(
          ongoing: _openEpisode != null,
          busy: _busy,
          onPressed: _togglePeriod,
        ),
        const SizedBox(height: 12),
        if (!hasData)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '记录首次经期后开始预测',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
      ],
    );
  }
}

/// 横向时间线：今−9 … 今+20，自动滚到今日。
class _DateTimelineStrip extends StatefulWidget {
  const _DateTimelineStrip({
    required this.daySets,
    required this.today,
    required this.onTapDay,
  });

  final CycleDaySets daySets;
  final DateTime today;
  final ValueChanged<DateTime> onTapDay;

  @override
  State<_DateTimelineStrip> createState() => _DateTimelineStripState();
}

class _DateTimelineStripState extends State<_DateTimelineStrip> {
  static const double _cellWidth = 48;
  static const int _daysBefore = 9;
  static const int _total = 30;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final viewport = _controller.position.viewportDimension;
      final target = _daysBefore * _cellWidth - (viewport - _cellWidth) / 2;
      final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
      _controller.jumpTo(clamped);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = CycleDates.addDays(widget.today, -_daysBefore);
    return SizedBox(
      height: 84,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 12),
            for (var i = 0; i < _total; i++)
              _TimelineDayCell(
                date: CycleDates.addDays(start, i),
                today: widget.today,
                daySets: widget.daySets,
                width: _cellWidth,
                onTap: widget.onTapDay,
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _TimelineDayCell extends StatelessWidget {
  const _TimelineDayCell({
    required this.date,
    required this.today,
    required this.daySets,
    required this.width,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final CycleDaySets daySets;
  final double width;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = CycleDates.dateKey(date) == CycleDates.dateKey(today);
    final key = CycleDates.dateKey(date);

    return InkWell(
      onTap: () => onTap(date),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              CycleDates.weekdayShort(date.weekday),
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? AppTheme.cycleAccent : Colors.transparent,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday ? Colors.white : AppTheme.cycleTextNavy,
                ),
              ),
            ),
            const SizedBox(height: 4),
            DayMarkers(
              sets: daySets,
              dateKey: key,
              symptomColor: AppTheme.cycleSymptom,
            ),
          ],
        ),
      ),
    );
  }
}

/// 倒计时 / 经期中 / 逾期 状态卡片。
class _CycleInfoCard extends StatelessWidget {
  const _CycleInfoCard({
    required this.prediction,
    required this.openEpisode,
    required this.lastClosed,
    required this.today,
  });

  final CyclePrediction prediction;
  final PeriodEpisode? openEpisode;
  final PeriodEpisode? lastClosed;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = prediction.nextPeriodStart;
    final open = openEpisode;
    final last = lastClosed;

    String headline;
    String subtitle;
    Color headlineColor = AppTheme.cycleTextNavy;

    if (next == null) {
      headline = '等待首次记录';
      subtitle = '点下方按钮记录「月经来了」，之后即可预测';
    } else if (prediction.isCurrentlyMenstruating && open != null) {
      final dayN = CycleDates.daysBetween(open.startDate, today) + 1;
      final expectedEnd = CycleDates.addDays(
          open.startDate, prediction.averagePeriodLength - 1);
      headline = '经期中 · 第 $dayN 天';
      headlineColor = AppTheme.cycleRose;
      if (expectedEnd.isBefore(today)) {
        subtitle = '第 $dayN 天，比平均时长长了一点，记得多休息';
      } else {
        subtitle = '预计 ${CycleDates.formatMonthDay(expectedEnd)} 结束';
      }
    } else if (prediction.isOverdue) {
      headline = '经期可能延迟 ${prediction.overdueDays} 天';
      final expected = prediction.expectedStart ?? next;
      subtitle = '原预计 ${CycleDates.formatMonthDay(expected)}（已过）';
    } else {
      final d = prediction.daysUntilNext ?? 0;
      headline = d == 0 ? '预计今天开始' : '距下次经期还有 $d 天';
      subtitle = '预计开始日 ${CycleDates.formatMonthDay(next)}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: headlineColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.history, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                last == null
                    ? '上次经期：暂无记录'
                    : '上次经期：${CycleDates.formatMonthDay(last.startDate)} - ${CycleDates.formatMonthDay(last.endDate!)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 当前周期阶段卡片：阶段名 + 一句友好提醒/解释。
class _CyclePhaseCard extends StatelessWidget {
  const _CyclePhaseCard({required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _phaseInfo(phase);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.color.withValues(alpha: 0.12),
            ),
            child: Icon(info.icon, size: 20, color: info.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前 · ${info.title}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.cycleTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.tip,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color color, String title, String tip}) _phaseInfo(
        CyclePhase p) =>
    switch (p) {
      CyclePhase.menstrual => (
          icon: Icons.water_drop_outlined,
          color: AppTheme.cycleRose,
          title: '月经期',
          tip: '身体在放慢、整理，多喝温水早点睡，这几天别太拼，好好照顾自己。',
        ),
      CyclePhase.follicular => (
          icon: Icons.eco_outlined,
          color: AppTheme.cycleAccent,
          title: '卵泡期',
          tip: '能量正在爬升，脑子会格外清醒，适合把重要的事安排在这几天。',
        ),
      CyclePhase.ovulation => (
          icon: Icons.wb_sunny_outlined,
          color: AppTheme.cycleSymptom,
          title: '排卵期',
          tip: '状态和心情都在高点，社交、运动都顺手，记得保持好心情、尽情发光。',
        ),
      CyclePhase.luteal => (
          icon: Icons.nightlight_round,
          color: AppTheme.cycleSymptomGray,
          title: '黄体期',
          tip: '能量慢慢回落，容易累、情绪也敏感，给自己留点缓冲，别硬扛。',
        ),
      CyclePhase.unknown => (
          icon: Icons.circle_outlined,
          color: AppTheme.cycleSymptomGray,
          title: '',
          tip: '',
        ),
    };

/// 一键切换：无进行中 →「月经来了」（实心）；有 →「结束了」（描边）。
class _PeriodToggleButton extends StatelessWidget {
  const _PeriodToggleButton({
    required this.ongoing,
    required this.busy,
    required this.onPressed,
  });

  final bool ongoing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = busy ? '请稍候...' : (ongoing ? '结束了' : '月经来了');
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    if (ongoing) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.cycleRose,
            side: const BorderSide(color: AppTheme.cycleRose),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: shape,
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cycleRose,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: shape,
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
