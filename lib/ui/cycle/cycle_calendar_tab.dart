import 'package:flutter/material.dart';

import '../../models/cycle_settings.dart';
import '../../models/day_record.dart';
import '../../models/period_episode.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_episode_editor.dart';
import '../../theme/app_theme.dart';
import 'cycle_widgets.dart';
import 'day_detail_sheet.dart';

/// 日历页：月份网格 + 点某天打开详情弹层（有月经开关 / 经量 / 痛经 / 备注）。
class CycleCalendarTab extends StatefulWidget {
  const CycleCalendarTab({
    super.key,
    required this.episodes,
    required this.daySets,
    required this.dayRecords,
    required this.settings,
    required this.today,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onDataChanged,
  });

  final List<PeriodEpisode> episodes;
  final CycleDaySets daySets;
  final Map<String, DayRecord> dayRecords;
  final CycleSettings settings;
  final DateTime today;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onSelectDate;
  final Future<void> Function() onDataChanged;

  @override
  State<CycleCalendarTab> createState() => _CycleCalendarTabState();
}

class _CycleCalendarTabState extends State<CycleCalendarTab> {
  late DateTime _visibleMonth; // 当月 1 号

  String? get _selectedKey => widget.selectedDate == null
      ? null
      : CycleDates.dateKey(widget.selectedDate!);

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.today.year, widget.today.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _openDayDetail(DateTime date) async {
    final key = CycleDates.dateKey(date);
    final existing = widget.dayRecords[key];
    widget.onSelectDate(date);
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
      await widget.onDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecord =
        _selectedKey == null ? null : widget.dayRecords[_selectedKey];
    final selected = widget.selectedDate;

    return SingleChildScrollView(
      child: Column(
        children: [
          _MonthHeader(
            month: _visibleMonth,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 8),
          const _WeekdayRow(),
          const SizedBox(height: 8),
          _MonthGrid(
            month: _visibleMonth,
            today: widget.today,
            daySets: widget.daySets,
            selectedDate: selected,
            onTapDay: _openDayDetail,
          ),
          if (selected != null)
            _DaySummaryCard(
              date: selected,
              record: selectedRecord,
              isPeriodDay: CycleEpisodeEditor.isPeriodDay(
                widget.episodes,
                selected,
                today: widget.today,
              ),
              onEdit: () => _openDayDetail(selected),
              onClose: () => widget.onSelectDate(null),
            ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
              CycleDates.formatYearMonth(month),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.cycleTextNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(l,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.daySets,
    required this.selectedDate,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime today;
  final CycleDaySets daySets;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // 周一 = 0
    final selectedKey =
        selectedDate == null ? null : CycleDates.dateKey(selectedDate!);

    final items = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _CalendarDayCell(
          date: DateTime(month.year, month.month, d),
          today: today,
          daySets: daySets,
          selected: CycleDates.dateKey(DateTime(month.year, month.month, d)) ==
              selectedKey,
          onTap: onTapDay,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: items,
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.today,
    required this.daySets,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final CycleDaySets daySets;
  final bool selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = CycleDates.dateKey(date) == CycleDates.dateKey(today);
    final key = CycleDates.dateKey(date);
    return InkWell(
      onTap: () => onTap(date),
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? AppTheme.cycleAccent : Colors.transparent,
              border: selected && !isToday
                  ? Border.all(color: AppTheme.cycleAccent, width: 1.5)
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isToday ? Colors.white : AppTheme.cycleTextNavy,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 2),
          DayMarkers(
            sets: daySets,
            dateKey: key,
            symptomColor: AppTheme.cycleSymptomGray,
          ),
        ],
      ),
    );
  }
}

/// 选中某天的摘要卡：回显经期状态 / 经量 / 痛经 / 备注。
class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.date,
    required this.record,
    required this.isPeriodDay,
    required this.onEdit,
    required this.onClose,
  });

  final DateTime date;
  final DayRecord? record;
  final bool isPeriodDay;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSymptom = record?.hasSymptom ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${CycleDates.formatMonthDay(date)} · ${CycleDates.weekdayShort(date.weekday)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.cycleTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: '编辑',
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
                tooltip: '收起',
              ),
            ],
          ),
          if (!isPeriodDay && !hasSymptom)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '这一天还没有记录，点 ✎ 添加',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(label: isPeriodDay ? '有月经' : '无月经', highlighted: isPeriodDay),
                if (record?.flow != null) _Tag(label: _flowLabel(record!.flow!)),
                if (record?.cramps != null)
                  _Tag(label: _crampLabel(record!.cramps!)),
              ],
            ),
            if (record?.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                record!.note!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.cycleTextNavy),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.cycleRose
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: highlighted ? Colors.white : AppTheme.cycleTextNavy,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

String _flowLabel(FlowLevel f) => switch (f) {
      FlowLevel.light => '经量·少',
      FlowLevel.medium => '经量·中',
      FlowLevel.heavy => '经量·多',
    };

String _crampLabel(CrampLevel c) => switch (c) {
      CrampLevel.mild => '痛经·轻微',
      CrampLevel.moderate => '痛经·中等',
      CrampLevel.severe => '痛经·严重',
    };

