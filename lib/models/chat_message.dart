class ChatMessage {
  static int _nextMessageId = 0;

  final String id;
  String original;
  bool isFinal;
  String? translation;
  final DateTime timestamp;

  final int? speaker;

  ChatMessage(
    this.original, {
    this.speaker,
    this.isFinal = false,
    String? id,
    DateTime? timestamp,
  }) : id = id ?? 'msg_${_nextMessageId++}',
       timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    if (speaker != null) {
      return 'Speaker ${speaker! + 1}: $original';
    }
    return original;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      json['original'] as String,
      speaker: json['speaker'] as int?,
      isFinal: json['isFinal'] as bool? ?? false,
      id: json['id'] as String?,
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    )..translation = json['translation'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'speaker': speaker,
      'isFinal': isFinal,
      'translation': translation,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
