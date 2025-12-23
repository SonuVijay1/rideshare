import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In future, when auth is added, this will use the real UID.
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demoUser';

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text(
                  'No account data found.\nCreate users/demoUser in Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final data = snapshot.data!.data() ?? {};

            final name = (data['name'] as String?) ?? 'Guest User';
            final phone = (data['phone'] as String?) ?? 'No phone';
            final passengerRating =
                (data['passengerRating'] as num?)?.toDouble() ?? 0.0;
            final ridesTaken = (data['ridesTaken'] as num?)?.toInt() ?? 0;
            final amountSaved =
                (data['amountSaved'] as num?)?.toDouble() ?? 0.0;

            final driverRating =
                (data['driverRating'] as num?)?.toDouble() ?? 0.0;
            final ridesOffered =
                (data['ridesOffered'] as num?)?.toInt() ?? 0;
            final amountEarned =
                (data['amountEarned'] as num?)?.toDouble() ?? 0.0;

            final initials = _getInitials(name);

            return Column(
              children: [
                // ---------- HEADER ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          const Text(
                            "Account",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              // later: open settings
                            },
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Profile block
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.deepPurple,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // later: navigate to Edit Profile
                            },
                            child: const Text(
                              "Edit",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ---------- BODY ----------
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        // Passenger stats card
                        _statsCard(
                          title: "Passenger Stats",
                          rating: passengerRating,
                          rides: ridesTaken,
                          moneyLabel: "Amount Saved",
                          moneyValue: amountSaved,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        // Driver stats card
                        _statsCard(
                          title: "Driver Stats",
                          rating: driverRating,
                          rides: ridesOffered,
                          moneyLabel: "Amount Earned",
                          moneyValue: amountEarned,
                          icon: Icons.directions_car,
                        ),
                        const SizedBox(height: 24),

                        // Menu items
                        _menuItem(
                          icon: Icons.edit,
                          label: "Edit Profile",
                          onTap: () {
                            // TODO: navigate to Edit Profile
                          },
                        ),
                        _menuItem(
                          icon: Icons.history,
                          label: "Trip History",
                          onTap: () {
                            // TODO: navigate to Trips screen
                          },
                        ),
                        _menuItem(
                          icon: Icons.payment,
                          label: "Payment Methods",
                          onTap: () {
                            // TODO
                          },
                        ),
                        _menuItem(
                          icon: Icons.place,
                          label: "Saved Locations",
                          onTap: () {
                            // TODO
                          },
                        ),
                        _menuItem(
                          icon: Icons.help_outline,
                          label: "Help & Support",
                          onTap: () {
                            // TODO
                          },
                        ),
                        _menuItem(
                          icon: Icons.info_outline,
                          label: "About App",
                          onTap: () {
                            // TODO
                          },
                        ),
                        const SizedBox(height: 16),

                        // Logout
                        _logoutButton(onTap: () {
                          // later: FirebaseAuth.instance.signOut();
                        }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- helpers ----------

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.isNotEmpty
          ? parts.first[0].toUpperCase()
          : '?';
    }
    final first = parts[0].isNotEmpty ? parts[0][0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    final result = (first + last).toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  Widget _statsCard({
    required String title,
    required double rating,
    required int rides,
    required String moneyLabel,
    required double moneyValue,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem(
                label: "Rating",
                value: rating == 0 ? "--" : rating.toStringAsFixed(1),
                icon: Icons.star,
              ),
              _statItem(
                label: "Rides",
                value: rides.toString(),
                icon: Icons.directions_car_filled_outlined,
              ),
              _statItem(
                label: moneyLabel,
                value: "₹${moneyValue.toStringAsFixed(0)}",
                icon: Icons.currency_rupee,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  Widget _logoutButton({required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.redAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            "Logout",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
