import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropController = TextEditingController();
  final TextEditingController carModelController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int seats = 1;

  // Pick Date
  Future<void> pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  // Pick Time
  Future<void> pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => selectedTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Offer a Ride",
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Pickup
              buildInputField("Pickup Location", pickupController),

              const SizedBox(height: 15),

              // Drop
              buildInputField("Drop Location", dropController),

              const SizedBox(height: 15),

              // Date picker
              buildPickerCard(
                label: "Select Date",
                value: selectedDate == null
                    ? "Pick Date"
                    : DateFormat('dd MMM yyyy').format(selectedDate!),
                onTap: pickDate,
              ),

              const SizedBox(height: 15),

              // Time picker
              buildPickerCard(
                label: "Select Time",
                value: selectedTime == null
                    ? "Pick Time"
                    : selectedTime!.format(context),
                onTap: pickTime,
              ),

              const SizedBox(height: 15),

              // Seats selector
              buildSeatsCard(),

              const SizedBox(height: 15),

              // Car Model
              buildInputField("Car Model (optional)", carModelController),

              const SizedBox(height: 15),

              // Car Number
              buildInputField("Car Number (optional)", carNumberController),

              const SizedBox(height: 30),

              // Publish Ride Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // add ride publish logic later
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ride Published Successfully!")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Publish Ride",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Reusable input filled card
  Widget buildInputField(String hint, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Reusable picker card
  Widget buildPickerCard({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Seats selector
  Widget buildSeatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Available Seats", style: TextStyle(color: Colors.white70)),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (seats > 1) setState(() => seats--);
                },
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
              Text("$seats", style: const TextStyle(color: Colors.white, fontSize: 18)),
              IconButton(
                onPressed: () => setState(() => seats++),
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          )
        ],
      ),
    );
  }
}
