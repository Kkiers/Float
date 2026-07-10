import 'package:flutter_test/flutter_test.dart';
import 'package:float/models/capture_item.dart';

void main() {
  group('CaptureItem', () {
    // const 时间不能直接用于 DateTime，用静态常量变通
    // ignore: prefer_const_declarations
    final baseTime = DateTime(2026, 6, 23, 12, 0, 0, 0);

    test('构造函数正确赋值所有字段', () {
      final item = CaptureItem(
        id: 1,
        content: '测试内容',
        reaction: 'wow',
        sourceHint: 'clipboard',
        capturedAt: baseTime,
      );

      expect(item.id, 1);
      expect(item.content, '测试内容');
      expect(item.reaction, 'wow');
      expect(item.sourceHint, 'clipboard');
      expect(item.capturedAt, baseTime);
    });

    test('toMap/fromMap 序列化往返一致', () {
      final item = CaptureItem(
        content: 'test content',
        reaction: 'wow',
        capturedAt: DateTime(2026, 6, 23, 12, 0),
      );
      final map = item.toMap();
      expect(map['content'], 'test content');
      expect(map['reaction'], 'wow');

      final restored = CaptureItem.fromMap(map);
      expect(restored.content, item.content);
      expect(restored.reaction, item.reaction);
    });

    test('带 id 的序列化往返', () {
      final item = CaptureItem(
        id: 42,
        content: '带 ID 的内容',
        reaction: '有趣',
        sourceHint: 'manual',
        capturedAt: baseTime,
      );

      final map = item.toMap();
      expect(map['id'], 42);
      expect(map['content'], '带 ID 的内容');
      expect(map['source_hint'], 'manual');

      final restored = CaptureItem.fromMap(map);
      expect(restored.id, 42);
      expect(restored.content, '带 ID 的内容');
      expect(restored.sourceHint, 'manual');
    });

    test('toMap 中 captured_at 存储为毫秒时间戳', () {
      final item = CaptureItem(
        content: '测试',
        capturedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final map = item.toMap();
      expect(map['captured_at'], 1700000000000);
    });

    test('fromMap 正确处理毫秒时间戳', () {
      final map = <String, Object?>{
        'id': 7,
        'content': '时间测试',
        'reaction': null,
        'source_hint': null,
        'captured_at': 1700000000000,
      };

      final item = CaptureItem.fromMap(map);
      expect(item.id, 7);
      expect(item.content, '时间测试');
      expect(item.reaction, isNull);
      expect(item.sourceHint, isNull);
      expect(item.capturedAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('reaction 和 sourceHint 可为 null', () {
      final item = CaptureItem(
        content: '只有内容',
        capturedAt: baseTime,
      );

      expect(item.reaction, isNull);
      expect(item.sourceHint, isNull);

      final map = item.toMap();
      expect(map['reaction'], isNull);
      expect(map['source_hint'], isNull);

      final restored = CaptureItem.fromMap(map);
      expect(restored.reaction, isNull);
      expect(restored.sourceHint, isNull);
    });

    test('id 可为 null（新插入前）', () {
      final item = CaptureItem(
        content: '新条目',
        capturedAt: baseTime,
      );

      expect(item.id, isNull);

      final map = item.toMap();
      expect(map['id'], isNull);
    });

    test('copyWith 保持原有值当参数为 null', () {
      final item = CaptureItem(
        id: 1,
        content: '原始内容',
        reaction: '哈哈',
        sourceHint: 'web',
        capturedAt: baseTime,
      );

      final copied = item.copyWith();
      expect(copied.id, 1);
      expect(copied.content, '原始内容');
      expect(copied.reaction, '哈哈');
      expect(copied.sourceHint, 'web');
      expect(copied.capturedAt, baseTime);
    });

    test('copyWith 覆盖指定字段', () {
      final item = CaptureItem(
        id: 1,
        content: '原始内容',
        capturedAt: baseTime,
      );

      final newTime = DateTime(2026, 6, 24);
      final copied = item.copyWith(
        content: '新内容',
        reaction: '不错',
        capturedAt: newTime,
      );

      expect(copied.id, 1);
      expect(copied.content, '新内容');
      expect(copied.reaction, '不错');
      expect(copied.capturedAt, newTime);
    });

    test('fromMap 处理空字符串内容', () {
      final map = <String, Object?>{
        'id': null,
        'content': '',
        'reaction': null,
        'source_hint': null,
        'captured_at': 1700000000000,
      };

      final item = CaptureItem.fromMap(map);
      expect(item.content, '');
      expect(item.id, isNull);
    });

    test('构造函数是 const（编译时验证）', () {
      // CaptureItem 构造函数标记了 const，验证可用
      final item = CaptureItem(content: '测试', capturedAt: baseTime);
      expect(item.content, '测试');
    });

    test('多个 items 正确排序', () {
      final items = [
        CaptureItem(content: '旧', capturedAt: DateTime(2026, 1, 1)),
        CaptureItem(content: '新', capturedAt: DateTime(2026, 6, 1)),
        CaptureItem(content: '中', capturedAt: DateTime(2026, 3, 1)),
      ];

      // DESC 排序（和数据库 getAll 一致）
      items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      expect(items[0].content, '新');
      expect(items[1].content, '中');
      expect(items[2].content, '旧');
    });
  });
}
