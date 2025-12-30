import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String title;

  const ChatScreen({super.key, required this.rideId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

  String? _currentUserName;
  Timer? _debounce;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final user = _userRepo.currentUser;
    if (user != null) {
      final data = await _userRepo.getUser(user.uid);
      if (mounted) {
        setState(() {
          _currentUserName = data?['name'] ?? 'User';
        });
      }
    }
  }

  void _onType(String text) {
    final user = _userRepo.currentUser;
    if (user == null) return;

    if (!_isTyping) {
      _isTyping = true;
      _rideRepo.setTypingStatus(
          widget.rideId, user.uid, _currentUserName ?? 'User', true);
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _rideRepo.setTypingStatus(
          widget.rideId, user.uid, _currentUserName ?? 'User', false);
    });
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final user = _userRepo.currentUser;
    if (user == null) return;

    // Use cached name if available
    String name = _currentUserName ?? 'User';
    if (_currentUserName == null) {
      final userData = await _userRepo.getUser(user.uid);
      name = userData?['name'] ?? 'User';
      _currentUserName = name;
    }

    _rideRepo.sendMessage(widget.rideId, _controller.text.trim(), user.uid, name);
    _controller.clear();

    // Clear typing status immediately
    if (_isTyping) {
      _isTyping = false;
      _debounce?.cancel();
      _rideRepo.setTypingStatus(widget.rideId, user.uid, name, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1F25), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _rideRepo.getMessages(widget.rideId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white));
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                              "No messages yet. Start the conversation!",
                              style: TextStyle(color: Colors.white54)),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['senderId'] == user?.uid;
                          return _messageBubble(msg, isMe);
                        },
                      );
                    },
                  ),
                ),
                _typingIndicator(),
                _inputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.white10,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(msg['senderName'] ?? 'User',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            if (!isMe) const SizedBox(height: 4),
            Text(msg['text'] ?? '',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    final user = _userRepo.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<List<String>>(
      stream: _rideRepo.getTypingUsers(widget.rideId, user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }
        final names = snapshot.data!;
        String text;
        if (names.length == 1) {
          text = "${names.first} is typing...";
        } else if (names.length == 2) {
          text = "${names[0]} and ${names[1]} are typing...";
        } else {
          text = "Multiple people are typing...";
        }

        return Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 4),
          child: Text(
            text,
            style: const TextStyle(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
                fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _inputArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onType,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
