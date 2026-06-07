import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddClientPage extends StatefulWidget {
  const AddClientPage({super.key});

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();

  String? dealType = "Buy"; // Buy/Rent
  String? propertyType = "Residential"; // Residential/Commercial/Other

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController areasController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  Future<void> _addClient() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection("clients").add({
        "dealType": dealType,
        "propertyType": propertyType,
        "clientName": nameController.text,
        "contactNumber": phoneController.text,
        "budget": budgetController.text,
        "areas": areasController.text,
        "remarks": remarksController.text,
        "status": "Open", // default status when adding
        "createdAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Client added successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Client"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: dealType,
                decoration: const InputDecoration(labelText: "Buy / Rent"),
                items: const [
                  DropdownMenuItem(value: "Buy", child: Text("Buy")),
                  DropdownMenuItem(value: "Rent", child: Text("Rent")),
                ],
                onChanged: (value) => setState(() => dealType = value),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: propertyType,
                decoration: const InputDecoration(labelText: "Property Type"),
                items: const [
                  DropdownMenuItem(value: "Residential", child: Text("Residential")),
                  DropdownMenuItem(value: "Commercial", child: Text("Commercial")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) => setState(() => propertyType = value),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Client Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter client name" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: budgetController,
                decoration: const InputDecoration(labelText: "Budget"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: areasController,
                decoration: const InputDecoration(labelText: "Areas"),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(labelText: "Remarks"),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _addClient,
                child: const Text(
                  "Add Client",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}