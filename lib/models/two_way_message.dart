enum TwoWaySpeaker { primary, guest }

class TwoWayMessage {

  TwoWayMessage({
    required this.speaker,
    required this.primaryText,
    required this.guestText,
  }) : timestamp = DateTime.now();
  final TwoWaySpeaker speaker;
  final String primaryText;
  final String guestText;
  final DateTime timestamp;
}
