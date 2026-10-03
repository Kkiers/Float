import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/capture_item.dart';
import '../services/ai_settings.dart';
import '../services/capture_storage.dart';
import '../services/chat_storage.dart';
import '../theme/app_theme.dart';
import 'ai_chat_page.dart';
import 'capture_card.dart';
import 'capture_detail_page.dart';
import 'capture_search_page.dart';
import 'model_picker_sheet.dart';

/// 首页视图：瀑布流 / 日历。
enum _WallView { flow, calendar }

/// 新版首页「墙」：搜索框独立一行 + 分段控件（瀑布流/日历）+ 顶部「今日遇见」卡片。
class CaptureWallPage extends StatefulWidget {
  const CaptureWallPage({super.key});

  @override
  State<CaptureWallPage> createState() => _CaptureWallPageState();
}

class _CaptureWallPageState extends State<CaptureWallPage> {
  List<CaptureItem> _items = const [];
  bool _loading = true;
  _WallView _view = _WallView.flow;
  late DateTime _calMonth;
  late DateTime _selectedDay;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  String _meetCadence = 'daily';
  CaptureItem? _meetShown;
  bool _meetRandomized = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _load();
    _loadCadence();
  }

  Future<void> _load() async {
    final items = await CaptureStorage.instance.getAll();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
        if (!_meetRandomized) _meetShown = _deterministicMeet(items);
      });
    }
  }

  Future<void> _loadCadence() async {
    final c = await AiSettings.instance.meetCadence();
    if (mounted) setState(() => _meetCadence = c);
  }

  Future<void> _openDetailAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureDetailPage(items: _items, initialIndex: index),
      ),
    );
    // 详情页里可能发生了「追加到原想法 / 存为新想法」，返回后统一刷新。
    await _load();
  }

  void _openDetail(CaptureItem item) {
    final index = _items.indexOf(item);
    _openDetailAt(index < 0 ? 0 : index);
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureSearchPage()),
    );
  }

  // ── 多选 ──────────────────────────────────────────────

  void _enterSelection(CaptureItem item) {
    setState(() {
      _selectionMode = true;
      if (item.id != null) _selectedIds.add(item.id!);
    });
  }

  void _toggleSelect(CaptureItem item) {
    if (item.id == null) return;
    setState(() {
      if (!_selectedIds.remove(item.id!)) {
        _selectedIds.add(item.id!);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    final allSelected = _selectedIds.length == _items.length && _items.isNotEmpty;
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map((e) => e.id).whereType<int>());
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这些想法？'),
        content: Text('将删除选中的 ${ids.length} 条想法，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in ids) {
      await CaptureStorage.instance.delete(id);
      await ChatStorage.instance.deleteForCapture(id);
    }
    _exitSelection();
    await _load();
  }

  Future<void> _askAiSelected() async {
    final selected = _items.where((it) => _selectedIds.contains(it.id)).toList();
    if (selected.isEmpty) return;
    final contextText = selected
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.content}')
        .join('\n');
    final persona = await showModelPicker(context);
    if (persona == null || !mounted) return;
    _exitSelection();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatPage(
          persona: persona,
          contextLabel: '选中的想法',
          initialContext: contextText,
          captureId: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      content = _empty(theme);
    } else {
      content = switch (_view) {
        _WallView.flow => _wall(theme),
        _WallView.calendar => _calendar(theme),
      };
    }

    return Column(
      children: [
        _header(theme),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: content,
          ),
        ),
        if (_selectionMode) _selectionBar(theme),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: _searchBar(theme),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _segmentedControl(theme),
        ),
      ],
    );
  }

  Widget _segmentedControl(ThemeData theme) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _segment(theme, _WallView.flow, '瀑布流', Icons.grid_view_rounded),
          _segment(theme, _WallView.calendar, '日历', Icons.calendar_view_month_outlined),
        ],
      ),
    );
  }

  Widget _segment(ThemeData theme, _WallView view, String label, IconData icon) {
    final active = _view == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _view = view;
          _selectionMode = false;
          _selectedIds.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppTheme.cycleAccent : theme.colorScheme.outline,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppTheme.cycleTextNavy : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(ThemeData theme) {
    return InkWell(
      onTap: _openSearch,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '搜想法、语音、剪贴板…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 瀑布流 ──────────────────────────────────────────────

  Widget _wall(ThemeData theme) {
    final groups = _groupByDay();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _meetCard(theme),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Text(
              g.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          _masonryRow(g.items),
        ],
      ],
    );
  }

  List<_DayGroup> _groupByDay() {
    final result = <_DayGroup>[];
    final now = DateTime.now();
    for (final it in _items) {
      final d = DateTime(it.capturedAt.year, it.capturedAt.month, it.capturedAt.day);
      final label = _dayLabel(d, now);
      if (result.isNotEmpty && result.last.label == label) {
        result.last.items.add(it);
      } else {
        result.add(_DayGroup(label)..items.add(it));
      }
    }
    return result;
  }

  String _dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (day.year == now.year) return DateFormat('M月d日').format(day);
    return DateFormat('yyyy年M月d日').format(day);
  }

  Widget _masonryRow(List<CaptureItem> items) {
    final left = <CaptureItem>[];
    final right = <CaptureItem>[];
    double lh = 0, rh = 0;
    for (final it in items) {
      final h = _estHeight(it);
      if (lh <= rh) {
        left.add(it);
        lh += h;
      } else {
        right.add(it);
        rh += h;
      }
    }

    Widget column(List<CaptureItem> list) => Column(
          children: [
            for (final it in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _wallCard(it),
              ),
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: 12),
        Expanded(child: column(right)),
      ],
    );
  }

  Widget _wallCard(CaptureItem it) {
    return CaptureCard(
      item: it,
      selected: _selectedIds.contains(it.id),
      onTap: () => _selectionMode ? _toggleSelect(it) : _openDetail(it),
      onLongPress: () => _enterSelection(it),
    );
  }

  double _estHeight(CaptureItem item) {
    final type = captureTypeOf(item);
    final badge = type == CaptureType.text ? 0.0 : 24.0;
    final lines = (item.content.length / 13).ceil().clamp(1, 3);
    return badge + lines * 20.0 + 44.0;
  }

  // ── 日历热力图 ──────────────────────────────────────────

  Widget _calendar(ThemeData theme) {
    final days = _captureDays();
    final first = _calMonth;
    final daysInMonth = DateTime(_calMonth.year, _calMonth.month + 1, 0).day;
    final leading = first.weekday - 1; // 周一 = 0
    final today = DateTime.now();

    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final dayItems = _items
        .where((it) => DateFormat('yyyy-MM-dd').format(it.capturedAt) == selectedKey)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(
                    () => _calMonth = DateTime(_calMonth.year, _calMonth.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('yyyy年M月').format(_calMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.cycleTextNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                    () => _calMonth = DateTime(_calMonth.year, _calMonth.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const _WeekdayRow(),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _calendarCell(
                DateTime(_calMonth.year, _calMonth.month, d),
                days,
                today,
              ),
          ],
        ),
        const Divider(height: 16),
        Expanded(
          child: dayItems.isEmpty
              ? _dayEmpty(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${DateFormat('M月d日').format(_selectedDay)} · ${dayItems.length} 条',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cycleTextNavy,
                        ),
                      ),
                    ),
                    for (final it in dayItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _wallCard(it),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _dayEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              '这一天还没有捕获',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: AppTheme.cycleTextNavy, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> _captureDays() =>
      _items.map((it) => DateFormat('yyyy-MM-dd').format(it.capturedAt)).toSet();

  Widget _calendarCell(DateTime day, Set<String> days, DateTime today) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final has = days.contains(key);
    final isToday =
        day.year == today.year && day.month == today.month && day.day == today.day;
    final isSelected = day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;

    return InkWell(
      onTap: () => setState(() => _selectedDay = day),
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppTheme.cycleAccent
                  : isToday
                      ? AppTheme.cycleAccent.withValues(alpha: 0.16)
                      : Colors.transparent,
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.cycleAccent, width: 1.2)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? AppTheme.cycleAccent
                        : AppTheme.cycleTextNavy,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: has ? AppTheme.cycleAccent : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // ── 多选操作条 ──────────────────────────────────────────

  Widget _selectionBar(ThemeData theme) {
    final allSelected = _selectedIds.length == _items.length && _items.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _selectAll,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    allSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: AppTheme.cycleAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allSelected ? '取消全选' : '全选',
                    style: const TextStyle(fontSize: 14, color: AppTheme.cycleTextNavy),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '已选 ${_selectedIds.length}',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _askAiSelected,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('问 AI'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.cycleAccent),
            ),
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5484D)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelection,
              tooltip: '取消',
            ),
          ],
        ),
      ),
    );
  }

  // ── 今日遇见 ──────────────────────────────────────────

  CaptureItem? _deterministicMeet(List<CaptureItem> items) {
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final daySeed =
        DateTime(now.year, now.month, now.day).difference(DateTime(1970, 1, 1)).inDays;
    final seed = _meetCadence == 'weekly' ? (daySeed ~/ 7) : daySeed;
    return items[seed % items.length];
  }

  void _shuffleMeet() {
    if (_items.isEmpty) return;
    setState(() {
      _meetRandomized = true;
      var idx = _random.nextInt(_items.length);
      final current = _meetShown;
      if (_items.length > 1 && current != null) {
        final curIdx = _items.indexOf(current);
        if (curIdx >= 0) {
          while (idx == curIdx) {
            idx = _random.nextInt(_items.length);
          }
        }
      }
      _meetShown = _items[idx];
    });
  }

  Future<void> _toggleCadence() async {
    final next = _meetCadence == 'daily' ? 'weekly' : 'daily';
    await AiSettings.instance.setMeetCadence(next);
    if (mounted) {
      setState(() {
        _meetCadence = next;
        _meetRandomized = false;
        _meetShown = _deterministicMeet(_items);
      });
    }
  }

  Widget _meetCard(ThemeData theme) {
    final item = _meetShown;
    if (item == null) return const SizedBox.shrink();
    final type = captureTypeOf(item);
    final style = styleOf(type);
    final label = _meetCadence == 'weekly' ? '每周' : '每天';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppTheme.cycleAccent),
                    const SizedBox(width: 6),
                    const Text(
                      '今日遇见',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cycleTextNavy,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _toggleCadence,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: style.accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: style.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, size: 14, color: style.accent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _shuffleMeet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: style.accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 14, color: style.accent),
                            const SizedBox(width: 3),
                            Text(
                              '换一条',
                              style: TextStyle(
                                fontSize: 11,
                                color: style.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 12, color: style.accent),
                          const SizedBox(width: 4),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: style.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      relativeTime(item.capturedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppTheme.cycleTextNavy,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '这是很久以前捕捉到的一条，再遇见一次',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 空态 ───────────────────────────────────────────────

  Widget _empty(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Icon(Icons.auto_awesome_outlined,
            size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '还没有捕获',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.cycleTextNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '浮球在屏幕边缘，灵感来了长按它',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

class _DayGroup {
  _DayGroup(this.label);
  final String label;
  final List<CaptureItem> items = [];
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
              ),
            ),
          ),
      ],
    );
  }
}
