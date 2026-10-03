import 'package:flutter/material.dart';

import '../../models/day_record.dart';
import '../../models/period_episode.dart';
import '../../services/analytics_service.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_episode_editor.dart';
import '../../services/cycle_storage.dart';
import '../../theme/app_theme.dart';

/// 底部弹层：某天的「有月经/无月经」开关 + 经量 / 痛经 / 备注。
///
/// 主页时间线与日历共用。未来日（`date > today`）隐藏经期开关，仅可记症状。
class DayDetailSheet extends StatefulWidget {
  const DayDetailSheet({
    super.key,
    required this.date,
    required this.episodes,
    required this.today,
    required this.typicalPeriodLength,
    this.existing,
  });

  final DateTime date;
  final List<PeriodEpisode> episodes;
  final DateTime today;
  final int typicalPeriodLength;
  final DayRecord? existing;

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  FlowLevel? _flow;
  CrampLevel? _cramps;
  late final TextEditingController _noteCtrl;
  late bool _periodOn;
  late int _periodDays;
  bool _saving = false;

  bool get _isFuture =>
      CycleDates.dateOnly(widget.date).isAfter(CycleDates.dateOnly(widget.today));

  bool get _isPeriodDay => CycleEpisodeEditor.isPeriodDay(
        widget.episodes,
        widget.date,
        today: widget.today,
      );

  @override
  void initState() {
    super.initState();
    _flow = widget.existing?.flow;
    _cramps = widget.existing?.cramps;
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
    _periodOn = _isPeriodDay;
    final base = CycleEpisodeEditor.periodLengthOf(
          widget.episodes,
          widget.date,
          today: widget.today,
        ) ??
        widget.typicalPeriodLength;
    _periodDays = base.clamp(1, 10).toInt();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final note = _noteCtrl.text.trim();

      // 经期开关（未来日不处理；状态/持续天数有变化才写库）。
      if (!_isFuture) {
        final currentLen = CycleEpisodeEditor.periodLengthOf(
          widget.episodes,
          widget.date,
          today: widget.today,
        );
        final periodChanged = _periodOn != _isPeriodDay ||
            (_periodOn && currentLen != _periodDays);
        if (periodChanged) {
          final next = _periodOn
              ? CycleEpisodeEditor.setPeriodRange(
                  widget.episodes,
                  widget.date,
                  CycleDates.addDays(widget.date, _periodDays - 1),
                  true,
                  today: widget.today,
                )
              : CycleEpisodeEditor.setPeriodDay(
                  widget.episodes,
                  widget.date,
                  false,
                  today: widget.today,
                );
          await CycleStorage.instance.saveEpisodes(next);
          AnalyticsService.instance.trackEvent('cycle_period_day_toggled',
              properties: {
                'date': CycleDates.dateKey(widget.date),
                'on': _periodOn,
                'days': _periodOn ? _periodDays : 1,
              });
        }
      }

      await CycleStorage.instance.upsertDayRecord(DayRecord(
        date: CycleDates.dateKey(widget.date),
        flow: _flow,
        cramps: _cramps,
        note: note.isEmpty ? null : note,
      ));
      AnalyticsService.instance.trackEvent('cycle_day_record_saved',
          properties: {
            'date': CycleDates.dateKey(widget.date),
            'flow': _flow?.name,
            'cramps': _cramps?.name,
          });
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await CycleStorage.instance
          .deleteDayRecord(CycleDates.dateKey(widget.date));

      // 若该天是周期日，一并关掉。
      if (!_isFuture && _isPeriodDay) {
        final next = CycleEpisodeEditor.setPeriodDay(
          widget.episodes,
          widget.date,
          false,
          today: widget.today,
        );
        await CycleStorage.instance.saveEpisodes(next);
        AnalyticsService.instance.trackEvent('cycle_period_day_toggled',
            properties: {
              'date': CycleDates.dateKey(widget.date),
              'on': false,
            });
      }

      AnalyticsService.instance.trackEvent('cycle_day_record_deleted',
          properties: {'date': CycleDates.dateKey(widget.date)});
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _showDelete => widget.existing != null || (!_isFuture && _isPeriodDay);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cycleBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              CycleDates.formatMonthDay(widget.date),
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.cycleTextNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_isFuture) ...[
              const SizedBox(height: 20),
              Text('经期', style: _labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _ChoiceChip(
                    label: '有月经',
                    selected: _periodOn,
                    onTap: () => setState(() => _periodOn = true),
                  ),
                  _ChoiceChip(
                    label: '无月经',
                    selected: !_periodOn,
                    onTap: () => setState(() => _periodOn = false),
                  ),
                ],
              ),
              if (_periodOn) ...[
                const SizedBox(height: 16),
                Text('持续天数', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StepCircle(
                      icon: Icons.remove,
                      onTap: _periodDays > 1
                          ? () => setState(() => _periodDays--)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$_periodDays 天',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cycleTextNavy,
                        ),
                      ),
                    ),
                    _StepCircle(
                      icon: Icons.add,
                      onTap: _periodDays < 10
                          ? () => setState(() => _periodDays++)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            Text('经量', style: _labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in FlowLevel.values)
                  _ChoiceChip(
                    label: _flowLabel(f),
                    selected: _flow == f,
                    onTap: () => setState(() => _flow = _flow == f ? null : f),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('痛经', style: _labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChoiceChip(
                  label: '无',
                  selected: _cramps == null,
                  onTap: () => setState(() => _cramps = null),
                ),
                for (final c in CrampLevel.values)
                  _ChoiceChip(
                    label: _crampLabel(c),
                    selected: _cramps == c,
                    onTap: () => setState(() => _cramps = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('备注', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '记录心情、症状等（可选）',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_showDelete) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _delete(),
                      child: Text('删除',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.cycleRose,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? '保存中...' : '保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
        color: AppTheme.cycleTextNavy,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      );

  String _flowLabel(FlowLevel f) => switch (f) {
        FlowLevel.light => '少',
        FlowLevel.medium => '中',
        FlowLevel.heavy => '多',
      };

  String _crampLabel(CrampLevel c) => switch (c) {
        CrampLevel.mild => '轻微',
        CrampLevel.moderate => '中等',
        CrampLevel.severe => '严重',
      };
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cycleRose : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.cycleRose
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.cycleTextNavy,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : const Color(0xFFF0EDE8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.cycleTextNavy : const Color(0xFFC7C3BC),
        ),
      ),
    );
  }
}
