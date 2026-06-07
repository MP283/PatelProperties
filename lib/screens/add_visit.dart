import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddVisitPage extends StatefulWidget {
  const AddVisitPage({super.key});

  @override
  State<AddVisitPage> createState() => _AddVisitPageState();
}

class _AddVisitPageState extends State<AddVisitPage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedPropertyId;
  String? selectedClientId;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController remarksController = TextEditingController();
  String status = "Not Completed";

  String formatTo12Hour(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $period";
  }

  Future<void> _saveVisit() async {
    if (_formKey.currentState!.validate() &&
        selectedPropertyId != null &&
        selectedClientId != null &&
        selectedDate != null &&
        selectedTime != null) {
      await FirebaseFirestore.instance.collection("visits").add({
        "propertyId": selectedPropertyId,
        "clientId": selectedClientId,
        "date": "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}",
        // "time": "${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}",
        "time": formatTo12Hour(selectedTime!),
        "remarks": remarksController.text,
        "status": status,
        "createdAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Visit added successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Visit"),
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
                    initialDate: DateTime.now(),
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
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
                child: Text(selectedTime == null
                    ? "Select Time"
                    : "Time: ${formatTo12Hour(selectedTime!)}"),
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
                onPressed: _saveVisit,
                child: const Text(
                  "Save Visit",
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