import 'package:flutter/material.dart';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 26, backgroundColor: Colors.grey.shade200, child: const Icon(Icons.person)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Sarah Johnson', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('★ 4.9 (127)', style: TextStyle(color: Colors.orange)),
          ]),
          const Spacer(),
          const Icon(Icons.check_circle, color: Colors.green),
        ]),
        const SizedBox(height: 14),
        Row(children: const [
          Icon(Icons.schedule, color: Color(0xFF8B5CF6)), SizedBox(width:8), Text('Today, 2:30 PM')
        ]),
        const SizedBox(height: 12),
        Row(children: const [
          Icon(Icons.circle, color: Colors.orange, size: 12), SizedBox(width:8), Text('New York City')
        ]),
        const SizedBox(height: 8),
        Row(children: const [
          Icon(Icons.location_on, color: Color(0xFF8B5CF6)), SizedBox(width:8), Text('Boston')
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Text('\$45', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
          const SizedBox(width: 8),
          const Text('per person', style: TextStyle(color: Colors.black54)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Book Now', style: TextStyle(color: Colors.white)),
          )
        ])
      ]),
    );
  }
}
