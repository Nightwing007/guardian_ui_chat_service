import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentChatMessageWidget extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final bool isSeen;

  const ParentChatMessageWidget({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.isSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF1E3E62) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  isSeen ? Icons.done_all : Icons.check,
                  size: 14,
                  color: isSeen ? Colors.blue : Colors.white.withValues(alpha: 0.5),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
