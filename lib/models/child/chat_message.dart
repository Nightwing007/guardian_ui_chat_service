class ChatMessage {
  final int id;
  final String text;
  final DateTime time;
  final bool isMe;
  final bool isSeen;

  ChatMessage({
    required this.id,
    required this.text,
    required this.time,
    required this.isMe,
    required this.isSeen,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      text: map['text'] as String,
      time: DateTime.parse(map['time'] as String),
      isMe: (map['is_me'] as int) == 1,
      isSeen: (map['is_seen'] as int) == 1,
    );
  }
}