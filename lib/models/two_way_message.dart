enum TwoWaySpeaker { primary, guest }

class TwoWayMessage {
  final TwoWaySpeaker speaker;
  final String primaryText;
  final String guestText;
  final DateTime timestamp;

  TwoWayMessage({
    required this.speaker,
    required this.primaryText,
    required this.guestText,
  }) : timestamp = DateTime.now();
}
