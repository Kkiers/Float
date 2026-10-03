/// 一条「追加块」：对话里沉淀下来、追加到原想法下方的一段文字。
/// 与原想法正文分开存储，详情页里以独立小卡片展示，而不是拼进正文。
class CaptureAppend {
  const CaptureAppend({
    this.id,
    required this.captureId,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int captureId;
  final String content;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'capture_id': captureId,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CaptureAppend.fromMap(Map<String, Object?> map) {
    return CaptureAppend(
      id: map['id'] as int?,
      captureId: map['capture_id'] as int,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
