import 'package:flutter/material.dart';
import 'components/ride_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isIntercity = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFFA855F7)],
                          ),
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text('RideShare',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {})
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isIntercity = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isIntercity
                                    ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFA855F7)])
                                    : null,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text('Intercity',
                                  style: TextStyle(
                                    color: isIntercity ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isIntercity = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text('Within City',
                                  style: TextStyle(
                                    color: !isIntercity ? Colors.black87 : Colors.black54,
                                    fontWeight: FontWeight.w600))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Travel Between Cities,\nShare the Ride',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text(
                    'Find affordable and comfortable intercity rides with verified drivers',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RideCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
