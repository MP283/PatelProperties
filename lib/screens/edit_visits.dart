import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditVisitPage extends StatefulWidget {
  final String visitId;
  const EditVisitPage({super.key, required this.visitId});

  @override
  State<EditVisitPage> createState() => _EditVisitPageState();
}

class _EditVisitPageState extends State<EditVisitPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedPropertyId;
  String? selectedClientId;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController remarksController = TextEditingController();
  String status = "Not Completed";

  Future<void> _loadVisit() async {
    final doc = await FirebaseFirestore.instance.collection("visits").doc(widget.visitId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        selectedPropertyId = data["propertyId"];
        selectedClientId = data["clientId"];
        remarksController.text = data["remarks"] ?? "";
        status = data["status"] ?? "Not Completed";

        // parse date
        if (data["date"] != null) {
          final parts = (data["date"] as String).split("-");
          if (parts.length == 3) {
            selectedDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        }

        // parse time
        if (data["time"] != null) {
          final timeString = (data["time"] as String).trim();

          // Split into hour/minute and possible AM/PM
          final parts = timeString.split(":");
          if (parts.length == 2) {
            // Extract hour and minute digits
            final hourPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
            final minutePart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');

            int hour = int.tryParse(hourPart) ?? 0;
            int minute = int.tryParse(minutePart) ?? 0;

            // Handle AM/PM
            final upper = timeString.toUpperCase();
            if (upper.contains("PM") && hour < 12) {
              hour += 12;
            }
            if (upper.contains("AM") && hour == 12) {
              hour = 0;
            }

            // Clamp hour to valid range
            if (hour > 23) hour = 23;

            selectedTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      });
    }
  }

  Future<void> _updateVisit() async {
    if (_formKey.currentState!.validate() &&
        selectedPropertyId != null &&
        selectedClientId != null &&
        selectedDate != null &&
        selectedTime != null) {
      await FirebaseFirestore.instance.collection("visits").doc(widget.visitId).update({
        "propertyId": selectedPropertyId,
        "clientId": selectedClientId,
        "date": "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}",
        "time": "${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}",
        "remarks": remarksController.text,
        "status": status,
        "updatedAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Visit updated successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVisit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Visit"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Property dropdown
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("properties").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: selectedPropertyId,
                    decoration: const InputDecoration(labelText: "Property"),
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc["projectName"] ?? ""),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedPropertyId = value),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Client dropdown
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("clients").snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: selectedClientId,
                    decoration: const InputDecoration(labelText: "Client"),
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(doc["clientName"] ?? ""),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedClientId = value),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date picker
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Text(selectedDate == null
                    ? "Select Date"
                    : "Date: ${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}"),
              ),
              const SizedBox(height: 16),

              // Time picker
              TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
                child: Text(selectedTime == null
                    ? "Select Time"
                    : "Time: ${selectedTime!.format(context)}"),
              ),
              const SizedBox(height: 16),

              // Remarks
              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(labelText: "Remarks"),
              ),
              const SizedBox(height: 16),

              // Status dropdown
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: "Status"),
                items: const [
                  DropdownMenuItem(value: "Not Completed", child: Text("Not Completed")),
                  DropdownMenuItem(value: "Completed", child: Text("Completed")),
                ],
                onChanged: (value) => setState(() => status = value!),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _updateVisit,
                child: const Text(
                  "Update Visit",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}