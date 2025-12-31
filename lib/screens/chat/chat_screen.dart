import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String title;
  final String driverId;
  final bool isDriver;

  const ChatScreen(
      {super.key,
      required this.rideId,
      required this.title,
      required this.driverId,
      required this.isDriver});

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
  String? _targetUserId; // The ID of the person we are chatting with (for status)

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _determineTargetUser();
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

  Future<void> _determineTargetUser() async {
    if (!widget.isDriver) {
      // If I am passenger, target is driver
      setState(() => _targetUserId = widget.driverId);
    } else {
      // If I am driver, check if there is exactly one passenger
      final ride = await _rideRepo.getRide(widget.driverId, widget.rideId);
      final bookedUsers = ride?['bookedUsers'] as List<dynamic>? ?? [];
      if (bookedUsers.length == 1) {
        setState(() => _targetUserId = bookedUsers.first['uid']);
      }
      // If multiple passengers, we don't show specific online status in header
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

    _rideRepo.sendMessage(
        widget.rideId, _controller.text.trim(), user.uid, name);
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
        title: _buildAppBarTitle(),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _handleCallAction,
          ),
        ],
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

                      // Mark messages as read if they are not mine
                      if (user != null) {
                        _rideRepo.markMessagesAsRead(widget.rideId, user.uid);
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

  Widget _buildAppBarTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        if (_targetUserId != null)
          StreamBuilder<Map<String, dynamic>?>(
            stream: _userRepo.getUserStream(_targetUserId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data = snapshot.data!;
              final isOnline = data['isOnline'] == true;
              final lastSeen = data['lastSeen'];

              String statusText = "Offline";
              if (isOnline) {
                statusText = "Online";
              } else if (lastSeen != null) {
                // Handle Timestamp or DateTime
                DateTime? dt;
                if (lastSeen is DateTime) dt = lastSeen;
                // Firestore Timestamp handling if not converted by repo
                // if (lastSeen is Timestamp) dt = lastSeen.toDate();
                
                if (dt != null) {
                  final now = DateTime.now();
                  final diff = now.difference(dt);
                  if (diff.inMinutes < 60) {
                    statusText = "Last seen ${diff.inMinutes}m ago";
                  } else if (diff.inHours < 24) {
                    statusText = "Last seen ${DateFormat('h:mm a').format(dt)}";
                  } else {
                    statusText = "Last seen ${DateFormat('MMM d').format(dt)}";
                  }
                }
              }

              return Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 12));
            },
          ),
      ],
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
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(msg['text'] ?? '',
                      style: const TextStyle(color: Colors.white)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  _buildReadStatus(msg['isRead'] == true),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadStatus(bool isRead) {
    return Icon(
      Icons.done_all,
      size: 16,
      color: isRead ? Colors.lightBlueAccent : Colors.white54,
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

  Future<void> _handleCallAction() async {
    if (widget.isDriver) {
      _showPassengerList();
    } else {
      _callDriver();
    }
  }

  Future<void> _callDriver() async {
    final user = _userRepo.currentUser;
    if (user == null) return;

    // Check booking status
    final booking = await _rideRepo.getBookingForRide(user.uid, widget.rideId);
    if (booking == null || booking['status'] != 'Confirmed') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Phone number is visible only for confirmed bookings.")),
        );
      }
      return;
    }

    final driver = await _userRepo.getUser(widget.driverId);
    final phone = driver?['phone'] ?? driver?['phoneNumber'];

    if (phone != null && phone.isNotEmpty) {
      _launchCaller(phone);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver phone number not available.")),
        );
      }
    }
  }

  Future<void> _showPassengerList() async {
    final ride = await _rideRepo.getRide(widget.driverId, widget.rideId);
    if (ride == null) return;

    final bookedUsers =
        List<Map<String, dynamic>>.from(ride['bookedUsers'] ?? []);
    if (bookedUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No passengers have booked yet.")),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: bookedUsers.length,
        itemBuilder: (context, index) {
          final u = bookedUsers[index];
          return ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: Text(u['name'] ?? 'Passenger',
                style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.phone, color: Colors.greenAccent),
            onTap: () async {
              final userData = await _userRepo.getUser(u['uid']);
              final phone = userData?['phone'] ?? userData?['phoneNumber'];
              if (phone != null) {
                _launchCaller(phone);
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Phone number not available")));
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _launchCaller(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch';
      }
    } catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text("Contact Number",
                      style: TextStyle(color: Colors.white)),
                  content: Text(number,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 18)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"))
                  ],
                ));
      }
    }
  }
}
