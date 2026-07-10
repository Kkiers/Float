import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/analytics_service.dart';
import '../services/capture_storage.dart';
import '../services/overlay_manager.dart';
import 'capture_panel.dart';
import 'log_viewer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _tag = 'HomePage';

  bool _overlayGranted = false;
  bool _micGranted = false;
  bool _overlayActive = false;
  int _captureCount = 0;
  bool _busy = false;
  bool _initialized = false;
  String? _error;
  int _listRefreshKey = 0; // bump to force CaptureListPage reload

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.trackEvent('app_home_opened');
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 监听 App 生命周期：从设置页返回时重新检查权限
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.instance.debug(_tag, 'App 恢复前台，重新检查状态');
      // 无论之前什么状态，回到前台时强制刷新
      _busySafeReset();
      _refresh();
    }
  }

  /// 安全重置 busy 状态（用于从设置页返回等场景）
  void _busySafeReset() {
    if (_busy && mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    AnalyticsService.instance.debug(_tag, '刷新状态');
    bool granted = _overlayGranted;
    bool active = _overlayActive;
    int count = _captureCount;

    try {
      // 给每个平台调用加超时保护，避免卡死
      granted = await OverlayManager.hasOverlayPermission()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '检查悬浮窗权限失败', properties: {'error': e.toString()});
    }

    try {
      active = await OverlayManager.isOverlayActive()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '检查悬浮窗状态失败', properties: {'error': e.toString()});
    }

    try {
      count = await CaptureStorage.instance.count()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '读取数据库失败', properties: {'error': e.toString()});
    }

    final micStatus = await Permission.microphone.status;

    if (mounted) {
      setState(() {
        _overlayGranted = granted;
        _overlayActive = active;
        _captureCount = count;
        _micGranted = micStatus.isGranted;
        _initialized = true;
        _error = null;
        _listRefreshKey++; // force capture list to reload
      });
    }
  }

  Future<void> _requestMicPermission() async {
    AnalyticsService.instance.trackEvent('request_mic_permission_clicked');
    setState(() => _busy = true);
    try {
      final result = await Permission.microphone.request();
      if (mounted) setState(() => _micGranted = result.isGranted);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermission() async {
    AnalyticsService.instance.trackEvent('request_permission_clicked');
    setState(() => _busy = true);
    try {
      await OverlayManager.requestOverlayPermission()
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      AnalyticsService.instance.warning(_tag, '请求权限超时或失败', properties: {'error': e.toString()});
      // 超时后让用户手动去系统设置
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请在系统设置中手动开启"显示在其他应用的上层"权限'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // 回到前台后会通过 didChangeAppLifecycleState 刷新
      await _refresh();
      _busySafeReset();
    }
  }

  Future<void> _toggleOverlay() async {
    if (!_overlayGranted) {
      await _requestPermission();
      // 重新检查权限（此时 _refresh 已在 _requestPermission 中调用过）
      if (!_overlayGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要悬浮窗权限才能启动捕网，请先授权'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    AnalyticsService.instance.trackEvent('overlay_toggle',
        properties: {'active': !_overlayActive});
    setState(() => _busy = true);
    try {
      if (_overlayActive) {
        await OverlayManager.closeOverlay().timeout(const Duration(seconds: 5));
      } else {
        await OverlayManager.showOrb().timeout(const Duration(seconds: 5));
      }
      await _refresh();
    } catch (e) {
      AnalyticsService.instance.error(_tag, '切换悬浮窗失败', properties: {'error': e.toString()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _busySafeReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Float'),
        actions: [
          GestureDetector(
            onLongPress: () => LogViewer.show(context),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: OverlayManager.openAppSettings,
              tooltip: '系统设置',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HeroCard(captureCount: _captureCount),
            const SizedBox(height: 20),

            // 错误提示
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _StatusTile(
              icon: Icons.layers_outlined,
              title: '悬浮窗权限',
              subtitle: _initialized
                  ? (_overlayGranted ? '已授权' : '需要授权才能显示捕网')
                  : '检查中...',
              ok: _overlayGranted,
              action: _overlayGranted
                  ? null
                  : TextButton(
                      onPressed: _busy ? null : _requestPermission,
                      child: const Text('去授权'),
                    ),
            ),
            const SizedBox(height: 10),
            _StatusTile(
              icon: Icons.mic_outlined,
              title: '麦克风权限',
              subtitle: _initialized
                  ? (_micGranted ? '已授权' : '语音捕获需要麦克风')
                  : '检查中...',
              ok: _micGranted,
              action: _micGranted
                  ? null
                  : TextButton(
                      onPressed: _busy ? null : _requestMicPermission,
                      child: const Text('去授权'),
                    ),
            ),
            const SizedBox(height: 10),
            _StatusTile(
              icon: Icons.bubble_chart_outlined,
              title: '捕网状态',
              subtitle: _initialized
                  ? (_overlayActive ? '浮球运行中' : '未启动')
                  : '检查中...',
              ok: _overlayActive,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _busy || !_initialized ? null : _toggleOverlay,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_overlayActive ? Icons.stop : Icons.play_arrow),
              label: Text(_busy ? '请稍候...' : (_overlayActive ? '关闭捕网' : '启动捕网')),
            ),
            const SizedBox(height: 12),
            Text(
              '使用方式：刷内容时看到好观点 → 先复制 → 点浮球 → 捕获',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '已捕获',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: CaptureListPage(key: ValueKey(_listRefreshKey)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.captureCount});

  final int captureCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '灵感出现 → 一捞 → 继续思考',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '不是记笔记，是捕获。零摩擦，不打断心流。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.wb_incandescent_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '已捕获 $captureCount 条',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: ok ? theme.colorScheme.primary : theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (ok)
            Icon(Icons.check_circle,
                color: theme.colorScheme.primary, size: 20)
          else if (action != null)
            action!,
        ],
      ),
    );
  }
}
