import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/capture_item.dart';
import 'analytics_service.dart';

class CaptureStorage {
  CaptureStorage._();
  static final CaptureStorage instance = CaptureStorage._();
  static const _tag = 'CaptureStorage';

  Database? _db;

  /// 测试用：设置数据库路径。
  /// - `null`（默认）→ 使用 getDatabasesPath() + 'captures.db'
  /// - `inMemoryDatabasePath` → 使用内存数据库
  @visibleForTesting
  String? testDbPath;

  /// 测试用：关闭当前数据库并清空内部引用，让下一次操作重新打开数据库。
  @visibleForTesting
  Future<void> closeForTesting() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = testDbPath ?? join(await getDatabasesPath(), 'captures.db');
    AnalyticsService.instance.info(_tag, '打开数据库', properties: {'path': path});

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE captures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            reaction TEXT,
            source_hint TEXT,
            captured_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insert(CaptureItem item) async {
    final db = await database;
    final id = await db.insert('captures', item.toMap()..remove('id'));
    AnalyticsService.instance.trackEvent('db_insert', properties: {
      'id': id,
      'content_length': item.content.length,
      'has_reaction': item.reaction != null,
    });
    return id;
  }

  Future<List<CaptureItem>> getAll() async {
    final db = await database;
    final rows = await db.query(
      'captures',
      orderBy: 'captured_at DESC',
    );
    AnalyticsService.instance.debug(_tag, '查询全部', properties: {'count': rows.length});
    return rows.map(CaptureItem.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('captures', where: 'id = ?', whereArgs: [id]);
    AnalyticsService.instance.trackEvent('db_delete', properties: {'id': id});
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM captures');
    final c = Sqflite.firstIntValue(result) ?? 0;
    AnalyticsService.instance.debug(_tag, '计数', properties: {'count': c});
    return c;
  }
}
