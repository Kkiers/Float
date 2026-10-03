import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/capture_append.dart';
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
      version: 3,
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
        await _createChatTables(db);
        await _createAppendsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createChatTables(db);
        if (oldVersion < 3) await _createAppendsTable(db);
      },
    );
  }

  Future<void> _createAppendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE capture_appends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_id INTEGER NOT NULL,
        persona_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
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

  Future<List<CaptureItem>> search(String query) async {
    final db = await database;
    final like = '%$query%';
    final rows = await db.query(
      'captures',
      where: 'content LIKE ? OR source_hint LIKE ?',
      whereArgs: [like, like],
      orderBy: 'captured_at DESC',
    );
    AnalyticsService.instance.debug(_tag, '搜索', properties: {'query': query, 'count': rows.length});
    return rows.map(CaptureItem.fromMap).toList();
  }

  Future<CaptureItem?> getById(int id) async {
    final db = await database;
    final rows = await db.query(
      'captures',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CaptureItem.fromMap(rows.first);
  }

  /// 把一段文字作为「追加块」存到某条想法下方（独立小卡片，不拼进正文）。
  Future<void> appendBlock(int captureId, String content) async {
    final db = await database;
    await db.insert('capture_appends', {
      'capture_id': captureId,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    AnalyticsService.instance.trackEvent('db_append', properties: {'id': captureId});
  }

  /// 某条想法的全部追加块（旧→新）。
  Future<List<CaptureAppend>> getAppends(int captureId) async {
    final db = await database;
    final rows = await db.query(
      'capture_appends',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CaptureAppend.fromMap).toList();
  }

  /// 编辑想法正文（覆盖内容）。
  Future<void> updateContent(int id, String content) async {
    final db = await database;
    await db.update('captures', {'content': content}, where: 'id = ?', whereArgs: [id]);
    AnalyticsService.instance.trackEvent('db_edit', properties: {'id': id});
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('capture_appends', where: 'capture_id = ?', whereArgs: [id]);
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
