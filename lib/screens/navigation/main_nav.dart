import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import 'trip_his_screen.dart';
import '../messages/messages_screen.dart';
import 'account_screen.dart';
import '../../repositories/user_repository.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with WidgetsBindingObserver {
  int _index = 0;
  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userRepo.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    _userRepo.updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _userRepo.updateOnlineStatus(true);
    } else {
      _userRepo.updateOnlineStatus(false);
    }
  }

  final screens = [
    const HomeScreen(), // Ride
    TripHistoryScreen(), // Trips
    const MessagesScreen(), // Messages
    const AccountScreen(), // Account
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: "Ride",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_rounded),
            label: "Trips",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: "Messages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Account",
          ),
        ],
      ),
    );
  }
}
