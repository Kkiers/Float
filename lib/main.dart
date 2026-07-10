import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'ui/float_overlay.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化埋点服务
  final analytics = AnalyticsService.instance;
  analytics.info('App', '应用启动');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const FloatApp());
}

class FloatApp extends StatelessWidget {
  const FloatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Float',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}

/// 悬浮窗独立 Flutter 引擎入口（flutter_overlay_window 要求）
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloatOverlay());
}
