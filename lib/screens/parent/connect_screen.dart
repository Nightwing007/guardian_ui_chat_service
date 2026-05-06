import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/parent_chat_message_widget.dart';

class ConnectScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ConnectScreen({super.key, this.onBack});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/chat_messages.json');
      setState(() {
        _messages = json.decode(jsonString);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        "text": _controller.text.trim(),
        "time": TimeOfDay.now().format(context),
        "isme": true,
        "isseen": false, // Assume unread initially
      });
    });
    _controller.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: Text(
          'Connect',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade800,
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Arav',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.1), height: 1),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? const Center(child: Text('Error loading messages', style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return ParentChatMessageWidget(
                            text: msg['text'],
                            time: msg['time'],
                            isMe: msg['isme'],
                            isSeen: msg['isseen'] ?? false,
                          );
                        },
                      ),
          ),
          _buildInputArea(),
          const SizedBox(height: 80), // Offset for bottom navigation bar
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // Dark background matching design
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.mic_none, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Icon(Icons.attach_file, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF154B99), // Blue send button
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_upward, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
