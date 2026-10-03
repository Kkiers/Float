import 'package:flutter/material.dart';

import '../../models/cycle_settings.dart';
import '../../models/day_record.dart';
import '../../models/period_episode.dart';
import '../../services/analytics_service.dart';
import '../../services/cycle_dates.dart';
import '../../services/cycle_predictor.dart';
import '../../services/cycle_storage.dart';
import '../../theme/app_theme.dart';
import 'cycle_calendar_tab.dart';
import 'cycle_home_tab.dart';
import 'cycle_onboarding.dart';
import 'cycle_stats_tab.dart';
import 'cycle_widgets.dart';

/// 月经周期模块：数据宿主 + 三页签脚手架（主页 / 日历 / 统计）。
class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<PeriodEpisode> _episodes = const [];
  Map<String, DayRecord> _dayRecords = const {};
  CycleSettings _settings = const CycleSettings();
  CyclePrediction _prediction = const CyclePrediction(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    hasSufficientData: false,
    isCurrentlyMenstruating: false,
  );
  CycleDaySets _daySets = CycleDaySets.empty;
  DateTime _today = CycleDates.dateOnly(DateTime.now());
  DateTime? _selectedDate; // 当前选中日期（主页/日历共享，驱动日历摘要卡）
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final episodes = await CycleStorage.instance.getAllEpisodes();
    final records = await CycleStorage.instance.getAllDayRecords();
    final settings = await CycleStorage.instance.getSettings();
    final today = CycleDates.dateOnly(DateTime.now());
    final prediction = CyclePredictor()
        .predict(episodes: episodes, settings: settings, today: today);
    final daySets = CycleDaySets.from(
      episodes: episodes,
      dayRecords: records,
      prediction: prediction,
      today: today,
    );

    if (prediction.nextPeriodStart != null) {
      AnalyticsService.instance.trackEvent('cycle_prediction_shown', properties: {
        'next_start': CycleDates.dateKey(prediction.nextPeriodStart!),
        'days_until_next': prediction.daysUntilNext,
      });
    }

    if (mounted) {
      setState(() {
        _episodes = episodes;
        _dayRecords = {for (final r in records) r.date: r};
        _settings = settings;
        _prediction = prediction;
        _daySets = daySets;
        _today = today;
        _loading = false;
      });
    }
  }

  Future<void> _completeOnboarding({
    required DateTime lastStart,
    required int cycleLen,
    required int periodLen,
  }) async {
    final settings = CycleSettings(
      typicalCycleLength: cycleLen,
      typicalPeriodLength: periodLen,
      onboarded: true,
    );
    final end = CycleDates.addDays(lastStart, periodLen - 1);
    final today = CycleDates.dateOnly(DateTime.now());
    await CycleStorage.instance.saveSettings(settings);
    // 结束日落在今天或未来 → 经期尚未结束，记为「进行中」（open）。
    await CycleStorage.instance.insertEpisode(end.isAfter(today)
        ? PeriodEpisode(startDate: lastStart)
        : PeriodEpisode(startDate: lastStart, endDate: end));
    AnalyticsService.instance.trackEvent('cycle_onboarding_completed',
        properties: {
          'last_start': CycleDates.dateKey(lastStart),
          'cycle_length': cycleLen,
          'period_length': periodLen,
        });
    await _reload();
  }

  Future<void> _skipOnboarding() async {
    await CycleStorage.instance.saveSettings(_settings.copyWith(onboarded: true));
    AnalyticsService.instance.trackEvent('cycle_onboarding_skipped');
    await _reload();
  }

  void _onTabTapped(int index) {
    AnalyticsService.instance.trackEvent('cycle_tab_switched', properties: {
      'tab': const ['home', 'calendar', 'stats'][index],
    });
  }

  void _setSelectedDate(DateTime? date) {
    setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppTheme.cycleBackground,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_settings.onboarded) {
      return CycleOnboarding(
        onCompleted: _completeOnboarding,
        onSkipped: _skipOnboarding,
      );
    }

    return ColoredBox(
      color: AppTheme.cycleBackground,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            onTap: _onTabTapped,
            indicatorColor: AppTheme.cycleRose,
            labelColor: AppTheme.cycleTextNavy,
            unselectedLabelColor: Theme.of(context).colorScheme.outline,
            tabs: const [
              Tab(text: '主页'),
              Tab(text: '日历'),
              Tab(text: '统计'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CycleHomeTab(
                  episodes: _episodes,
                  settings: _settings,
                  prediction: _prediction,
                  daySets: _daySets,
                  today: _today,
                  onDataChanged: _reload,
                  onSelectDate: _setSelectedDate,
                ),
                CycleCalendarTab(
                  episodes: _episodes,
                  daySets: _daySets,
                  dayRecords: _dayRecords,
                  settings: _settings,
                  today: _today,
                  selectedDate: _selectedDate,
                  onSelectDate: _setSelectedDate,
                  onDataChanged: _reload,
                ),
                CycleStatsTab(
                  episodes: _episodes,
                  prediction: _prediction,
                  settings: _settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
