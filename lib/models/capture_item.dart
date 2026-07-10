class CaptureItem {
  const CaptureItem({
    this.id,
    required this.content,
    this.reaction,
    this.sourceHint,
    required this.capturedAt,
  });

  final int? id;
  final String content;
  final String? reaction;
  final String? sourceHint;
  final DateTime capturedAt;

  CaptureItem copyWith({
    int? id,
    String? content,
    String? reaction,
    String? sourceHint,
    DateTime? capturedAt,
  }) {
    return CaptureItem(
      id: id ?? this.id,
      content: content ?? this.content,
      reaction: reaction ?? this.reaction,
      sourceHint: sourceHint ?? this.sourceHint,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'content': content,
      'reaction': reaction,
      'source_hint': sourceHint,
      'captured_at': capturedAt.millisecondsSinceEpoch,
    };
  }

  factory CaptureItem.fromMap(Map<String, Object?> map) {
    return CaptureItem(
      id: map['id'] as int?,
      content: map['content'] as String,
      reaction: map['reaction'] as String?,
      sourceHint: map['source_hint'] as String?,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
    );
  }
}
