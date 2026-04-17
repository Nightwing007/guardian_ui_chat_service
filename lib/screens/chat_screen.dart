import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/chat_message_widget.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 100),
      // The bottom margin ensures we don't overlap the floating navigation bar
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppColors.primaryGradientEnd, AppColors.primaryGradientStart],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile Picture with Online indicator
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D5B7), // Placeholder color for generic user
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2A2A35), width: 2), // visually separate from avatar
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Name and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'ONLINE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
              ],
            ),
          ),
          // Call Button
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        ChatMessageWidget(
          text: 'Hi Alex, how was school today?',
          time: '3:45 PM',
          isMe: false,
        ),
        ChatMessageWidget(
          text: 'It was good 😌',
          time: '3:46 PM',
          isMe: true,
        ),
        ChatMessageWidget(
          text: 'Don\'t forget to sleep early tonight.',
          time: '3:50 PM',
          isMe: false,
        ),
        ChatMessageWidget(
          text: 'Okay!',
          time: '3:51 PM',
          isMe: true,
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Attachment Icon
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFF465A7E)),
            onPressed: () {},
          ),
          // Text Input
          Expanded(
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.all(0),
              ),
            ),
          ),
          // Mic Icon
          IconButton(
            icon: const Icon(Icons.mic_none_outlined, color: Color(0xFF465A7E)),
            onPressed: () {},
          ),
          // Send Button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF263238), // Dark send button wrapper
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.only(left: 4.0), // visual centering for send icon
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
