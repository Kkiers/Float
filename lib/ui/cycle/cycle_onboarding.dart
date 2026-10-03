import 'package:flutter/material.dart';

import '../../services/cycle_dates.dart';
import '../../theme/app_theme.dart';

/// 一步引导：填最近经期开始日 + 典型周期/经期天数，即可开始预测。
class CycleOnboarding extends StatefulWidget {
  const CycleOnboarding({
    super.key,
    required this.onCompleted,
    required this.onSkipped,
  });

  final Future<void> Function({
    required DateTime lastStart,
    required int cycleLen,
    required int periodLen,
  }) onCompleted;
  final Future<void> Function() onSkipped;

  @override
  State<CycleOnboarding> createState() => _CycleOnboardingState();
}

class _CycleOnboardingState extends State<CycleOnboarding> {
  DateTime _lastStart = CycleDates.dateOnly(DateTime.now());
  int _cycleLen = 28;
  int _periodLen = 5;
  bool _busy = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _lastStart = CycleDates.dateOnly(picked));
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onCompleted(
        lastStart: _lastStart,
        cycleLen: _cycleLen,
        periodLen: _periodLen,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: AppTheme.cycleBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '开始记录',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.cycleTextNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '回答两个问题，就能开始预测下一次经期。',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 28),
              const _FieldLabel('最近一次经期开始日'),
              _TappableCard(
                onTap: _pickDate,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 20, color: AppTheme.cycleAccent),
                    const SizedBox(width: 10),
                    Text(
                      CycleDates.formatMonthDay(_lastStart),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.cycleTextNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _FieldLabel('典型周期天数'),
              _Stepper(
                value: _cycleLen,
                min: 15,
                max: 60,
                suffix: '天',
                onChanged: (v) => setState(() => _cycleLen = v),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('典型经期天数'),
              _Stepper(
                value: _periodLen,
                min: 1,
                max: 14,
                suffix: '天',
                onChanged: (v) => setState(() => _periodLen = v),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : () => _submit(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cycleRose,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_busy ? '请稍候...' : '开始使用'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => widget.onSkipped(),
                  child: Text('跳过',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.cycleTextNavy,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TappableCard extends StatelessWidget {
  const _TappableCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.cycleTextNavy),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.cycleTextNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.cycleTextNavy),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
