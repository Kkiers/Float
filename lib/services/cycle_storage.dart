import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cycle_settings.dart';
import '../models/day_record.dart';
import '../models/period_episode.dart';
import 'analytics_service.dart';

/// 月经周期模块的本地存储（独立 `cycle.db`，不影响现有 `captures.db`）。
class CycleStorage {
  CycleStorage._();
  static final CycleStorage instance = CycleStorage._();
  static const _tag = 'CycleStorage';

  Database? _db;

  /// 测试用：设置数据库路径。
  @visibleForTesting
  String? testDbPath;

  /// 测试用：关闭当前数据库并清空内部引用。
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
    final path = testDbPath ?? join(await getDatabasesPath(), 'cycle.db');
    AnalyticsService.instance.info(_tag, '打开数据库', properties: {'path': path});

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE period_episodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_date TEXT NOT NULL,
            end_date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE day_records (
            date TEXT PRIMARY KEY,
            flow TEXT,
            cramps TEXT,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE cycle_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            typical_cycle_length INTEGER NOT NULL DEFAULT 28,
            typical_period_length INTEGER NOT NULL DEFAULT 5,
            onboarded INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // -------------------------------------------------------------------------
  // 经期事件
  // -------------------------------------------------------------------------

  Future<int> insertEpisode(PeriodEpisode episode) async {
    final db = await database;
    final id = await db.insert('period_episodes', episode.toMap()..remove('id'));
    AnalyticsService.instance.trackEvent('cycle_episode_insert',
        properties: {'id': id, 'start_date': episode.toMap()['start_date']});
    return id;
  }

  Future<void> updateEpisode(PeriodEpisode episode) async {
    if (episode.id == null) return;
    final db = await database;
    await db.update(
      'period_episodes',
      episode.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [episode.id],
    );
    AnalyticsService.instance
        .trackEvent('cycle_episode_update', properties: {'id': episode.id});
  }

  Future<void> deleteEpisode(int id) async {
    final db = await database;
    await db.delete('period_episodes', where: 'id = ?', whereArgs: [id]);
    AnalyticsService.instance
        .trackEvent('cycle_episode_delete', properties: {'id': id});
  }

  /// 用给定列表整体重写经期事件（事务：清空后重插，ID 无外部引用，安全）。
  /// 供补记编辑器（[CycleEpisodeEditor]）在按天开关后落库。
  Future<void> saveEpisodes(List<PeriodEpisode> episodes) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('period_episodes');
      for (final e in episodes) {
        await txn.insert('period_episodes', e.toMap()..remove('id'));
      }
    });
    AnalyticsService.instance
        .trackEvent('cycle_episodes_rewritten', properties: {'count': episodes.length});
  }

  Future<List<PeriodEpisode>> getAllEpisodes() async {
    final db = await database;
    final rows = await db.query('period_episodes', orderBy: 'start_date ASC');
    return rows.map(PeriodEpisode.fromMap).toList();
  }

  Future<PeriodEpisode?> getOpenEpisode() async {
    final db = await database;
    final rows = await db.query(
      'period_episodes',
      where: 'end_date IS NULL',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodEpisode.fromMap(rows.first);
  }

  Future<PeriodEpisode?> getLastClosedEpisode() async {
    final db = await database;
    final rows = await db.query(
      'period_episodes',
      where: 'end_date IS NOT NULL',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PeriodEpisode.fromMap(rows.first);
  }

  // -------------------------------------------------------------------------
  // 按天记录
  // -------------------------------------------------------------------------

  Future<void> upsertDayRecord(DayRecord record) async {
    final db = await database;
    await db.insert('day_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    AnalyticsService.instance
        .trackEvent('cycle_day_record_upsert', properties: {'date': record.date});
  }

  Future<DayRecord?> getDayRecord(String date) async {
    final db = await database;
    final rows =
        await db.query('day_records', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    return DayRecord.fromMap(rows.first);
  }

  Future<List<DayRecord>> getAllDayRecords() async {
    final db = await database;
    final rows = await db.query('day_records', orderBy: 'date ASC');
    return rows.map(DayRecord.fromMap).toList();
  }

  Future<List<DayRecord>> getDayRecordsBetween(String from, String to) async {
    final db = await database;
    final rows = await db.query(
      'day_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, to],
      orderBy: 'date ASC',
    );
    return rows.map(DayRecord.fromMap).toList();
  }

  Future<void> deleteDayRecord(String date) async {
    final db = await database;
    await db.delete('day_records', where: 'date = ?', whereArgs: [date]);
    AnalyticsService.instance
        .trackEvent('cycle_day_record_delete', properties: {'date': date});
  }

  // -------------------------------------------------------------------------
  // 设置
  // -------------------------------------------------------------------------

  Future<CycleSettings> getSettings() async {
    final db = await database;
    final rows = await db.query('cycle_settings', limit: 1);
    if (rows.isEmpty) return const CycleSettings();
    return CycleSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(CycleSettings settings) async {
    final db = await database;
    await db.insert('cycle_settings', settings.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    AnalyticsService.instance.trackEvent('cycle_settings_saved', properties: {
      'typical_cycle_length': settings.typicalCycleLength,
      'typical_period_length': settings.typicalPeriodLength,
    });
  }
}
