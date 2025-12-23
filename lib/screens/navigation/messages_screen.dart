import 'package:flutter/material.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: const Center(
        child: Text(
          "Messages",
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ),
    );
  }
}
