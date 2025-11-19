// lib/main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(const RideShareApp());
}

class RideShareApp extends StatelessWidget {
  const RideShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFFef9f5),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

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
          // Top gradient header
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
                  // App bar row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFFA855F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,4))],
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'RideShare',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {},
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Toggle tabs
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
                                color: isIntercity ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isIntercity
                                    ? [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,6))]
                                    : [],
                              ),
                              child: Center(
                                  child: Text(
                                'Intercity',
                                style: TextStyle(
                                  color: isIntercity ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isIntercity = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Within City',
                                  style: TextStyle(
                                    color: !isIntercity ? Colors.black87 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Travel Between Cities,\nShare the Ride',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find affordable and comfortable intercity rides with verified drivers',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // Body: Search card & results
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // Search card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0,10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('From', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        buildInput('City, Station'),
                        const SizedBox(height: 14),
                        const Text('To', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        buildInput('City, Station'),
                        const SizedBox(height: 14),
                        const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        buildInput('DD/MM/YYYY'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFA855F7)]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: const Center(child: Text('Search', style: TextStyle(color: Colors.white))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,6))]),
                              child: IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Example ride card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RideCard(),
                ),

                const SizedBox(height: 20),

                // CTA / Features section (short)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: const [
                      Text('Why Choose RideShare?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text('The smart way to travel with trusted companions', textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInput(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(hint, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }
}

class RideCard extends StatelessWidget {
  const RideCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0,10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person, color: Colors.grey)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Sarah Johnson', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('★ 4.9 (127)', style: TextStyle(color: Colors.orange)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: const [Icon(Icons.schedule, color: Color(0xFF8B5CF6)), SizedBox(width:8), Text('Today, 2:30 PM')]),
          const SizedBox(height: 12),
          Row(children: const [Icon(Icons.circle, color: Colors.orange, size: 12), SizedBox(width:8), Text('New York City')]),
          const SizedBox(height: 8),
          Row(children: const [Icon(Icons.location_on, color: Color(0xFF8B5CF6)), SizedBox(width:8), Text('Boston')]),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('\$45', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
              const SizedBox(width: 8),
              const Text('per person', style: TextStyle(color: Colors.black54)),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,6))],
                  ),
                  child: const Text('Book Now', style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
