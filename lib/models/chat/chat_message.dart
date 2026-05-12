class ChatMessageItem {
  final int? localId;
  final int? remoteId;
  final String text;
  final DateTime createdAt;
  final bool isMe;
  final bool isSeen;
  final String senderType;

  const ChatMessageItem({
    this.localId,
    this.remoteId,
    required this.text,
    required this.createdAt,
    required this.isMe,
    required this.isSeen,
    required this.senderType,
  });

  factory ChatMessageItem.fromDb(Map<String, Object?> row) {
    // Null-safe DateTime parse — fall back to now() if column is empty/invalid
    final createdRaw = row['created']?.toString() ?? '';
    DateTime createdAt;
    try {
      createdAt = createdRaw.isNotEmpty
          ? DateTime.parse(createdRaw)
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return ChatMessageItem(
      localId: row['id'] as int?,
      remoteId: row['remote_id'] as int?,
      text: row['text']?.toString() ?? '',
      createdAt: createdAt,
      isMe: (row['is_me'] as int? ?? 0) == 1,
      isSeen: (row['is_read'] as int? ?? 0) == 1,
      senderType: row['sender_type']?.toString() ?? '',
    );
  }
}
