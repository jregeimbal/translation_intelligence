class PlaybackDevice {

  const PlaybackDevice({
    required this.id,
    required this.name,
    required this.type,
  });
  final String id;
  final String name;
  final String type;

  String get displayName => name.isNotEmpty ? name : type;

  String get details {
    final normalizedType = type.trim();
    if (name.isEmpty && normalizedType.isEmpty) {
      return id;
    }
    if (name.isEmpty) {
      return normalizedType;
    }
    if (normalizedType.isEmpty) {
      return name;
    }
    return '$name ($normalizedType)';
  }
}
