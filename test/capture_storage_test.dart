import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:float/models/capture_item.dart';
import 'package:float/services/capture_storage.dart';

void main() {
  late DateTime fixedNow;

  setUpAll(() {
    // 初始化 FFI 数据库工厂，在桌面环境测试 SQLite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    fixedNow = DateTime(2026, 6, 23, 12, 0, 0, 0);
    // 使用内存数据库，每个 test 隔离
    CaptureStorage.instance.testDbPath = inMemoryDatabasePath;
    await CaptureStorage.instance.closeForTesting();
  });

  tearDown(() async {
    await CaptureStorage.instance.closeForTesting();
    CaptureStorage.instance.testDbPath = null;
  });

  group('CaptureStorage', () {
    test('插入新条目并验证 id 被分配', () async {
      final item = CaptureItem(
        content: '测试灵感',
        reaction: '不错',
        capturedAt: fixedNow,
      );

      // insert 前 id 为 null
      expect(item.id, isNull);

      final id = await CaptureStorage.instance.insert(item);
      expect(id, greaterThan(0));
    });

    test('getAll 返回空列表当数据库为空', () async {
      final items = await CaptureStorage.instance.getAll();
      expect(items, isEmpty);
    });

    test('插入一条后 getAll 返回该条目', () async {
      await CaptureStorage.instance.insert(
        CaptureItem(content: '内容1', capturedAt: fixedNow),
      );

      final items = await CaptureStorage.instance.getAll();
      expect(items.length, 1);
      expect(items.first.content, '内容1');
    });

    test('getAll 按 captured_at DESC 排序', () async {
      await CaptureStorage.instance.insert(
        CaptureItem(content: '最早', capturedAt: DateTime(2026, 1, 1)),
      );
      await CaptureStorage.instance.insert(
        CaptureItem(content: '最晚', capturedAt: DateTime(2026, 12, 31)),
      );
      await CaptureStorage.instance.insert(
        CaptureItem(content: '中间', capturedAt: DateTime(2026, 6, 1)),
      );

      final items = await CaptureStorage.instance.getAll();
      expect(items.length, 3);
      expect(items[0].content, '最晚');
      expect(items[1].content, '中间');
      expect(items[2].content, '最早');
    });

    test('插入的条目完整保留所有字段', () async {
      const reaction = '这个观点有意思，因为…';
      const sourceHint = 'manual';
      await CaptureStorage.instance.insert(
        CaptureItem(
          content: '完整测试',
          reaction: reaction,
          sourceHint: sourceHint,
          capturedAt: fixedNow,
        ),
      );

      final items = await CaptureStorage.instance.getAll();
      expect(items.length, 1);
      expect(items.first.id, isNotNull);
      expect(items.first.content, '完整测试');
      expect(items.first.reaction, reaction);
      expect(items.first.sourceHint, sourceHint);
      expect(items.first.capturedAt, fixedNow);
    });

    test('count 返回正确条目数', () async {
      expect(await CaptureStorage.instance.count(), 0);

      await CaptureStorage.instance
          .insert(CaptureItem(content: 'a', capturedAt: fixedNow));
      expect(await CaptureStorage.instance.count(), 1);

      await CaptureStorage.instance
          .insert(CaptureItem(content: 'b', capturedAt: fixedNow));
      expect(await CaptureStorage.instance.count(), 2);

      await CaptureStorage.instance
          .insert(CaptureItem(content: 'c', capturedAt: fixedNow));
      expect(await CaptureStorage.instance.count(), 3);
    });

    test('delete 移除指定条目', () async {
      final id1 = await CaptureStorage.instance.insert(
        CaptureItem(content: '要删除的', capturedAt: fixedNow),
      );
      final id2 = await CaptureStorage.instance.insert(
        CaptureItem(content: '保留的', capturedAt: fixedNow),
      );

      expect(await CaptureStorage.instance.count(), 2);

      await CaptureStorage.instance.delete(id1);

      expect(await CaptureStorage.instance.count(), 1);
      final remaining = await CaptureStorage.instance.getAll();
      expect(remaining.first.content, '保留的');
      expect(remaining.first.id, id2);
    });

    test('删除不存在的 id 不报错', () async {
      await CaptureStorage.instance.delete(999);
      // 应该静默成功
    });

    test('reaction 和 sourceHint 可为 null 并正确还原', () async {
      await CaptureStorage.instance.insert(
        CaptureItem(content: '无反应的捕获', capturedAt: fixedNow),
      );

      final items = await CaptureStorage.instance.getAll();
      expect(items.first.reaction, isNull);
      expect(items.first.sourceHint, isNull);
    });

    test('插入大量条目并验证 getAll 性能', () async {
      const count = 50;
      for (var i = 0; i < count; i++) {
        await CaptureStorage.instance.insert(
          CaptureItem(
            content: '条目 #$i',
            capturedAt: fixedNow.add(Duration(minutes: i)),
          ),
        );
      }

      final items = await CaptureStorage.instance.getAll();
      expect(items.length, count);
      // 验证 DESC 排序：最新的在第一个
      expect(items.first.content, '条目 #${count - 1}');
      expect(items.last.content, '条目 #0');
    });

    test('内存数据库隔离 — 重置后 count 为 0', () async {
      await CaptureStorage.instance
          .insert(CaptureItem(content: '数据', capturedAt: fixedNow));
      expect(await CaptureStorage.instance.count(), 1);

      // 关闭后再重新打开（内存数据库会被清空）
      await CaptureStorage.instance.closeForTesting();
      expect(await CaptureStorage.instance.count(), 0);
    });
  });
}
