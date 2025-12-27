import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------
// AUTH SCREENS (DISABLED FOR NOW)
// ---------------------
import 'auth/login_screen.dart';
// import 'auth/otp_screen.dart';
// import 'auth/signup_screen.dart';

// NAVIGATION
import 'screens/navigation/main_nav.dart';

// Other screens still used for routes
import 'screens/book/book_ride_screen.dart';
import 'screens/offer/offer_ride_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase initialized');
  } catch (e, st) {
    print('Firebase.initializeApp error: $e\n$st');
  }

  runApp(const RideShareApp());
}

class RideShareApp extends StatelessWidget {
  const RideShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideShare',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const Root(),

        // ---------------------
        // AUTH FLOW (DISABLED)
        // ---------------------
        '/login': (context) => const LoginScreen(),
        // '/otp': (context) => const OtpScreen(),
        // '/signup-profile': (context) => const SignupProfileScreen(),

        // APP ROUTES
        '/home': (context) => const MainNav(),
        '/book': (context) => const BookRideScreen(),
        '/offer': (context) => const OfferRideScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Auth error: ${snapshot.error}')),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainNav();
        }

        return const LoginScreen();
      },
    );
  }
}
