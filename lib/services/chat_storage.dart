import 'package:sqflite/sqflite.dart';

import '../models/chat_session.dart';
import 'capture_storage.dart';

/// 追问历史存储：读写与 CaptureStorage 同一数据库里的 chat_sessions / chat_messages。
class ChatStorage {
  ChatStorage._();
  static final ChatStorage instance = ChatStorage._();

  Future<Database> get _db => CaptureStorage.instance.database;

  Future<int> createSession(int captureId, String personaId) async {
    final db = await _db;
    return db.insert('chat_sessions', {
      'capture_id': captureId,
      'persona_id': personaId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> addMessage(int sessionId, String role, String content) async {
    final db = await _db;
    return db.insert('chat_messages', {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 某条想法下所有追问会话（新→旧），每个会话带各自消息。
  Future<List<ChatSession>> getSessions(int captureId) async {
    final db = await _db;
    final sessionRows = await db.query(
      'chat_sessions',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'created_at DESC',
    );
    final sessions = sessionRows.map(ChatSession.fromMap).toList();
    for (final s in sessions) {
      final msgRows = await db.query(
        'chat_messages',
        where: 'session_id = ?',
        whereArgs: [s.id],
        orderBy: 'created_at ASC',
      );
      s.messages = msgRows.map(ChatMessage.fromMap).toList();
    }
    return sessions;
  }

  /// 删除某条想法时，级联删除它的全部会话与消息。
  Future<void> deleteForCapture(int captureId) async {
    final db = await _db;
    final rows = await db.query(
      'chat_sessions',
      columns: ['id'],
      where: 'capture_id = ?',
      whereArgs: [captureId],
    );
    for (final r in rows) {
      final sessionId = r['id'] as int;
      await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [sessionId]);
    }
    await db.delete('chat_sessions', where: 'capture_id = ?', whereArgs: [captureId]);
  }
}
