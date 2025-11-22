import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/book/book_ride_screen.dart';
import 'screens/offer/offer_ride_screen.dart';
import 'screens/profile/profile_screen.dart';

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const BookRideScreen(),
    const OfferRideScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() => _currentIndex = index);
        },

        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: "Home"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: "Book"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              label: "Offer"
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: "Profile"
          ),
        ],
      ),
    );
  }
}
