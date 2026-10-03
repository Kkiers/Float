import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/analytics_service.dart';
import '../services/overlay_manager.dart';
import '../theme/app_theme.dart';
import 'capture_wall.dart';
import 'cycle/app_drawer.dart';
import 'cycle/app_section.dart';
import 'cycle/cycle_page.dart';
import 'log_viewer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _tag = 'HomePage';

  bool _overlayGranted = false;
  bool _overlayActive = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppSection _section = AppSection.float;
  bool _cycleLoaded = false; // 首次切到周期页签时才构建 CyclePage，避免启动即读库

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.trackEvent('app_home_opened');
    // 首帧后再检测权限 / 自动启动，避免在 build 前弹层。
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureReady(prompt: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从系统设置等页面返回时，重新检测并自动启动浮球（不再重复弹权限清单）。
      _ensureReady(prompt: false);
    }
  }

  /// 检测权限 → 缺了弹清单 → 有权限则自动启动浮球。
  Future<void> _ensureReady({required bool prompt}) async {
    bool overlayGranted = false;
    bool overlayActive = false;
    bool micGranted = false;

    try {
      overlayGranted =
          await OverlayManager.hasOverlayPermission().timeout(const Duration(seconds: 5));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '检查悬浮窗权限失败',
          properties: {'error': e.toString()});
    }
    try {
      overlayActive =
          await OverlayManager.isOverlayActive().timeout(const Duration(seconds: 5));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '检查悬浮窗状态失败',
          properties: {'error': e.toString()});
    }
    try {
      micGranted = (await Permission.microphone.status).isGranted;
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '检查麦克风权限失败',
          properties: {'error': e.toString()});
    }

    if (!mounted) return;
    setState(() {
      _overlayGranted = overlayGranted;
      _overlayActive = overlayActive;
    });

    // 有悬浮窗权限则自动浮起捕球（幂等）。
    if (overlayGranted && !overlayActive) {
      try {
        await OverlayManager.showOrb();
        if (mounted) setState(() => _overlayActive = true);
      } catch (e) {
        AnalyticsService.instance.warning(_tag, '自动启动浮球失败',
            properties: {'error': e.toString()});
      }
    }

    // 首次进入且权限未就绪 → 弹权限清单。
    if (prompt && (!overlayGranted || !micGranted)) {
      _showPermissionSheet(overlayGranted: overlayGranted, micGranted: micGranted);
    }
  }

  /// 权限清单弹层：只列出缺失项，各自带「去开启」。
  Future<void> _showPermissionSheet({
    required bool overlayGranted,
    required bool micGranted,
  }) async {
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '开启权限，捕球自动浮起',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cycleTextNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '只差一点点就能零摩擦捕获了',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              if (!overlayGranted)
                _permRow(
                  ctx,
                  icon: Icons.layers_outlined,
                  title: '悬浮窗权限',
                  subtitle: '让捕球显示在其他 App 之上',
                  value: 'overlay',
                ),
              if (!micGranted)
                _permRow(
                  ctx,
                  icon: Icons.mic_none,
                  title: '麦克风权限',
                  subtitle: '语音捕获需要麦克风',
                  value: 'mic',
                ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;
    if (action == 'overlay') {
      try {
        await OverlayManager.requestOverlayPermission()
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        AnalyticsService.instance.warning(_tag, '请求悬浮窗权限失败',
            properties: {'error': e.toString()});
      }
    } else if (action == 'mic') {
      await Permission.microphone.request();
    }
    if (mounted) await _ensureReady(prompt: false);
  }

  Widget _permRow(
    BuildContext sheetCtx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.onSurface),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: TextButton(
        onPressed: () => Navigator.of(sheetCtx).pop(value),
        child: const Text('去开启'),
      ),
    );
  }

  /// 手动切换浮球开关（AppBar 图标）。
  Future<void> _toggleOrb() async {
    if (_overlayActive) {
      try {
        await OverlayManager.closeOverlay().timeout(const Duration(seconds: 5));
      } catch (e) {
        AnalyticsService.instance.warning(_tag, '关闭浮球失败',
            properties: {'error': e.toString()});
      }
      if (mounted) setState(() => _overlayActive = false);
    } else {
      if (!_overlayGranted) {
        await _ensureReady(prompt: true);
        return;
      }
      try {
        await OverlayManager.showOrb().timeout(const Duration(seconds: 5));
        if (mounted) setState(() => _overlayActive = true);
      } catch (e) {
        AnalyticsService.instance.warning(_tag, '启动浮球失败',
            properties: {'error': e.toString()});
      }
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectSection(AppSection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      if (section == AppSection.cycle) _cycleLoaded = true;
    });
    AnalyticsService.instance.trackEvent('app_section_switched',
        properties: {'section': section.name});
    if (section == AppSection.cycle) {
      AnalyticsService.instance.trackEvent('cycle_module_opened');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(selected: _section, onSelect: _selectSection),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _openDrawer,
          tooltip: '菜单',
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Float',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '灵感出现 → 一捞 → 继续思考',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _overlayActive ? Icons.brightness_1 : Icons.brightness_1_outlined,
              size: 18,
              color: _overlayActive
                  ? AppTheme.orbCore
                  : theme.colorScheme.outline,
            ),
            onPressed: _toggleOrb,
            tooltip: _overlayActive ? '关闭捕球' : '启动捕球',
          ),
          GestureDetector(
            onLongPress: () => LogViewer.show(context),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => OverlayManager.openAppSettings(),
              tooltip: '系统设置',
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _section.index,
        children: [
          const CaptureWallPage(),
          _cycleLoaded ? const CyclePage() : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
