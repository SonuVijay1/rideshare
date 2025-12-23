import 'package:flutter/material.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: const Center(
        child: Text(
          "Your Trips will appear here",
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ),
    );
  }
}
