import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  final _formKey = GlobalKey<FormState>();

  String? sellOrRent = "Sell";
  String? propertyType = "Residential";

  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController bhkController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerNumberController = TextEditingController();
  final TextEditingController keysController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Property"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Sell / Rent dropdown
              DropdownButtonFormField<String>(
                value: sellOrRent,
                decoration: const InputDecoration(labelText: "Sell / Rent"),
                items: const [
                  DropdownMenuItem(value: "Sell", child: Text("Sell")),
                  DropdownMenuItem(value: "Rent", child: Text("Rent")),
                ],
                onChanged: (value) => setState(() => sellOrRent = value),
              ),
              const SizedBox(height: 16),

              // Property type dropdown
              DropdownButtonFormField<String>(
                value: propertyType,
                decoration: const InputDecoration(labelText: "Property Type"),
                items: const [
                  DropdownMenuItem(value: "Residential", child: Text("Residential")),
                  DropdownMenuItem(value: "Commercial", child: Text("Commercial")),
                  DropdownMenuItem(value: "Others", child: Text("Others")),
                ],
                onChanged: (value) => setState(() => propertyType = value),
              ),
              const SizedBox(height: 16),

              // Project name
              TextFormField(
                controller: projectNameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter project name" : null,
              ),
              const SizedBox(height: 16),

              // BHK
              TextFormField(
                controller: bhkController,
                decoration: const InputDecoration(labelText: "BHK"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Owner Name
              TextFormField(
                controller: ownerNameController,
                decoration: const InputDecoration(labelText: "Owner Name"),
              ),
              const SizedBox(height: 16),

              // Owner Number
              TextFormField(
                controller: ownerNumberController,
                decoration: const InputDecoration(labelText: "Owner Number"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Keys
              TextFormField(
                controller: keysController,
                decoration: const InputDecoration(labelText: "Keys"),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await FirebaseFirestore.instance.collection("properties").add({
                      "sellOrRent": sellOrRent,
                      "propertyType": propertyType,
                      "projectName": projectNameController.text,
                      "bhk": bhkController.text,
                      "price": priceController.text,
                      "ownerName": ownerNameController.text,
                      "ownerNumber": ownerNumberController.text,
                      "keys": keysController.text,
                      "createdAt": DateTime.now(),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Property added successfully!")),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Add Property",
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