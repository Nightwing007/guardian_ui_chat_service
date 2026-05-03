import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatMessageWidget extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;

  const ChatMessageWidget({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF55D68B) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isMe ? 24 : 8),
                bottomRight: Radius.circular(isMe ? 8 : 24),
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isMe ? Colors.white : const Color(0xFF2C3E50),
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
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check, // Or double check if we use a stacked icon
                  size: 12,
                  color: Color(0xFF55D68B),
                ),
                const Icon(
                  Icons.check,
                  size: 12,
                  color: Color(0xFF55D68B),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
