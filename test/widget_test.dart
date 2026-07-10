import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
// import sqflite_common_ffi/sqflite_ffi.dart';

import 'package:float/models/capture_item.dart';
import 'package:float/services/capture_storage.dart';
import 'package:float/ui/capture_panel.dart';

// ---------------------------------------------------------------------------
// 测试辅助：mock 平台通道
// ---------------------------------------------------------------------------

/// 注册 flutter_overlay_window 的 mock 通道
void _mockOverlayWindowChannel({
  bool isPermissionGranted = false,
  bool isActive = false,
}) {
  // 主通道：权限、开关等
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('x-slayer/overlay_channel'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermission':
          return isPermissionGranted;
        case 'requestPermission':
          return true;
        case 'showOverlay':
          return null;
        case 'closeOverlay':
          return true;
        default:
          return null;
      }
    },
  );

  // 操作通道：resize、move、flag 等
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('x-slayer/overlay'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'resizeOverlay':
          return true;
        case 'isActive':
          return isActive;
        default:
          return null;
      }
    },
  );
}

/// 注册 permission_handler 的 mock 通道
void _mockPermissionHandlerChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.permissionhandler'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    },
  );
}

/// 注册剪贴板的 mock 通道（Flutter 内置使用 flutter/platform 通道）
/// 只处理 Clipboard.getData，其他请求抛 MissingPluginException 让框架兜底。
void _mockClipboardChannel({String? clipboardText}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter/platform'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.getData') {
        if (clipboardText != null) {
          return {'text': clipboardText};
        }
        return null;
      }
      // 其他平台方法交给 Flutter 框架默认处理
      throw MissingPluginException('Unhandled: ${methodCall.method}');
    },
  );
}

/// 清理所有 mock 通道
void _resetMockChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('x-slayer/overlay_channel'), null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('x-slayer/overlay'), null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.permissionhandler'), null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter/platform'), null,
  );
}

// ---------------------------------------------------------------------------
// 测试正文
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    CaptureStorage.instance.testDbPath = inMemoryDatabasePath;
    await CaptureStorage.instance.closeForTesting();
    _mockOverlayWindowChannel();
    _mockPermissionHandlerChannel();
    _mockClipboardChannel();
  });

  tearDown(() async {
    await CaptureStorage.instance.closeForTesting();
    CaptureStorage.instance.testDbPath = null;
    _resetMockChannels();
  });

  /// 创建 CapturePanel 测试用 widget
  Widget buildPanel({VoidCallback? onClose}) {
    return MaterialApp(
      home: Scaffold(
        body: CapturePanel(onClose: onClose ?? () {}),
      ),
    );
  }

  /// 创建 CaptureListPage 测试用 widget
  Widget buildListPage() {
    return const MaterialApp(
      home: Scaffold(body: CaptureListPage()),
    );
  }

  /// TextField 的光标闪烁会导致 pumpAndSettle 永不结束。
  /// 用 pumpFrame 代替：等固定帧数让异步操作完成。
  Future<void> pumpFrame(WidgetTester tester, {int times = 3}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('CapturePanel', () {
    testWidgets('显示标题和输入框', (tester) async {
      await tester.pumpWidget(buildPanel());
      await pumpFrame(tester);

      expect(find.text('捕获灵感'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('捕获 ✓'), findsOneWidget);
    });

    testWidgets('空内容时点击捕获按钮不保存', (tester) async {
      await tester.pumpWidget(buildPanel());
      await pumpFrame(tester);

      await tester.tap(find.text('捕获 ✓'));
      await pumpFrame(tester);

      expect(await CaptureStorage.instance.count(), 0);
    });

    testWidgets('输入内容后点击捕获保存到数据库', (tester) async {
      var closed = false;
      await tester.pumpWidget(buildPanel(onClose: () => closed = true));
      await pumpFrame(tester);

      await tester.enterText(find.byType(TextField).first, '测试灵感内容');
      await tester.tap(find.text('捕获 ✓'));
      await pumpFrame(tester, times: 5);

      expect(await CaptureStorage.instance.count(), 1);
      final items = await CaptureStorage.instance.getAll();
      expect(items.first.content, '测试灵感内容');
      expect(closed, isTrue);
    });

    testWidgets('从剪贴板自动填充内容', (tester) async {
      // 在 pumpWidget 之前设置剪贴板 mock
      _mockClipboardChannel(clipboardText: '来自剪贴板的内容');

      await tester.pumpWidget(buildPanel());
      // 多 pump 几次让异步 _loadClipboard 完成
      await pumpFrame(tester, times: 10);

      expect(find.text('来自剪贴板的内容'), findsOneWidget);
    });

    testWidgets('添加反应备注并保存', (tester) async {
      var closed = false;
      await tester.pumpWidget(buildPanel(onClose: () => closed = true));
      await pumpFrame(tester);

      await tester.enterText(find.byType(TextField).first, '灵感内容');
      await tester.tap(find.text('说说为什么兴奋'));
      await pumpFrame(tester);

      expect(find.text('为什么这个点打动你？（可选）'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '太棒了！');

      await tester.tap(find.text('捕获 ✓'));
      await pumpFrame(tester, times: 5);

      final items = await CaptureStorage.instance.getAll();
      expect(items.first.reaction, '太棒了！');
      expect(items.first.content, '灵感内容');
      expect(closed, isTrue);
    });

    testWidgets('点击关闭按钮触发 onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(buildPanel(onClose: () => closed = true));
      await pumpFrame(tester);

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrame(tester);

      expect(closed, isTrue);
    });
  });

  group('CaptureListPage', () {
    testWidgets('空状态显示提示', (tester) async {
      await tester.pumpWidget(buildListPage());
      await pumpFrame(tester, times: 5);

      expect(find.text('还没有捕获'), findsOneWidget);
      expect(find.text('开启浮球，灵感来了点一下'), findsOneWidget);
    });

    testWidgets('显示已保存的条目列表', (tester) async {
      await CaptureStorage.instance.insert(
        CaptureItem(
          content: '条目 A',
          reaction: '好',
          capturedAt: DateTime(2026, 6, 23, 12, 0),
        ),
      );
      await CaptureStorage.instance.insert(
        CaptureItem(content: '条目 B', capturedAt: DateTime(2026, 6, 24, 12, 0)),
      );

      await tester.pumpWidget(buildListPage());
      await pumpFrame(tester, times: 5);

      expect(find.text('条目 B'), findsOneWidget);
      expect(find.text('条目 A'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
    });

    testWidgets('滑动删除条目后列表更新', (tester) async {
      await CaptureStorage.instance.insert(
        CaptureItem(content: '将被删除的', capturedAt: DateTime(2026, 6, 23)),
      );
      await CaptureStorage.instance.insert(
        CaptureItem(content: '保留的', capturedAt: DateTime(2026, 6, 24)),
      );

      await tester.pumpWidget(buildListPage());
      await pumpFrame(tester, times: 5);

      await tester.drag(find.text('保留的'), const Offset(-500, 0));
      await pumpFrame(tester, times: 5);

      expect(await CaptureStorage.instance.count(), 1);
      expect(find.text('保留的'), findsNothing);
      expect(find.text('将被删除的'), findsOneWidget);
    });
  });
}
