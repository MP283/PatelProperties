import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPropertyPage extends StatefulWidget {
  final String propertyId;

  const EditPropertyPage({super.key, required this.propertyId});

  @override
  State<EditPropertyPage> createState() => _EditPropertyPageState();
}

class _EditPropertyPageState extends State<EditPropertyPage> {
  final _formKey = GlobalKey<FormState>();

  String? sellOrRent;
  String? propertyType;

  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController bhkController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerNumberController = TextEditingController();
  final TextEditingController keysController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    final doc = await FirebaseFirestore.instance
        .collection("properties")
        .doc(widget.propertyId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        sellOrRent = data["sellOrRent"];
        propertyType = data["propertyType"];
        projectNameController.text = data["projectName"] ?? "";
        bhkController.text = data["bhk"] ?? "";
        priceController.text = data["price"] ?? "";
        ownerNameController.text = data["ownerName"] ?? "";
        ownerNumberController.text = data["ownerNumber"] ?? "";
        keysController.text = data["keys"] ?? "";
        isLoading = false;
      });
    }
  }

  Future<void> _updateProperty() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection("properties")
          .doc(widget.propertyId)
          .update({
        "sellOrRent": sellOrRent,
        "propertyType": propertyType,
        "projectName": projectNameController.text,
        "bhk": bhkController.text,
        "price": priceController.text,
        "ownerName": ownerNameController.text,
        "ownerNumber": ownerNumberController.text,
        "keys": keysController.text,
        "updatedAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Property updated successfully!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Property"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                controller: projectNameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter project name" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: bhkController,
                decoration: const InputDecoration(labelText: "BHK"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ownerNameController,
                decoration: const InputDecoration(labelText: "Owner Name"),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ownerNumberController,
                decoration: const InputDecoration(labelText: "Owner Number"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: keysController,
                decoration: const InputDecoration(labelText: "Keys"),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _updateProperty,
                child: const Text(
                  "Update Property",
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