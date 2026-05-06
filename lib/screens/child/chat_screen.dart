import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/chat_message_widget.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/models/child/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = AppDatabase();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _db.child.getChatMessages();
    await _db.child.markMessagesAsSeen();
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    await _db.child.sendChatMessage(text);
    await _loadMessages();
    
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 100),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _buildMessageList(),
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
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4D5B7),
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
                    border: Border.all(color: const Color(0xFF2A2A35), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: GoogleFonts.poppins(color: AppColors.textGrey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return ChatMessageWidget(
          text: msg.text,
          time: _formatTime(msg.time),
          isMe: msg.isMe,
        );
      },
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
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFF465A7E)),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.all(0),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none_outlined, color: Color(0xFF465A7E)),
            onPressed: () {},
          ),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF263238),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}