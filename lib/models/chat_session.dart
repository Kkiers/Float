/// 一条追问消息：user 或 assistant 的一次发言。
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int sessionId;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, Object?> map) {
    return ChatMessage(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// 一次追问会话：某条想法 + 某个思维模型 + 一组消息。
class ChatSession {
  ChatSession({
    this.id,
    required this.captureId,
    required this.personaId,
    required this.createdAt,
    this.messages = const [],
  });

  final int? id;
  final int captureId;
  final String personaId;
  final DateTime createdAt;
  List<ChatMessage> messages;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'capture_id': captureId,
      'persona_id': personaId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChatSession.fromMap(Map<String, Object?> map) {
    return ChatSession(
      id: map['id'] as int?,
      captureId: map['capture_id'] as int,
      personaId: map['persona_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
