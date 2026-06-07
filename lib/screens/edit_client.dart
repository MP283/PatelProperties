import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditClientPage extends StatefulWidget {
  final String clientId;

  const EditClientPage({super.key, required this.clientId});

  @override
  State<EditClientPage> createState() => _EditClientPageState();
}

class _EditClientPageState extends State<EditClientPage> {
  final _formKey = GlobalKey<FormState>();

  String? dealType;
  String? propertyType;
  String? status;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController areasController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClient();
  }

  Future<void> _loadClient() async {
    final doc = await FirebaseFirestore.instance
        .collection("clients")
        .doc(widget.clientId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        dealType = data["dealType"];
        propertyType = data["propertyType"];
        status = data["status"];
        nameController.text = data["clientName"] ?? "";
        phoneController.text = data["contactNumber"] ?? "";
        budgetController.text = data["budget"] ?? "";
        areasController.text = data["areas"] ?? "";
        remarksController.text = data["remarks"] ?? "";
        isLoading = false;
      });
    }
  }

  Future<void> _updateClient() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection("clients")
          .doc(widget.clientId)
          .update({
        "dealType": dealType,
        "propertyType": propertyType,
        "status": status,
        "clientName": nameController.text,
        "contactNumber": phoneController.text,
        "budget": budgetController.text,
        "areas": areasController.text,
        "remarks": remarksController.text,
        "updatedAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Client updated successfully!")),
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
        title: const Text("Edit Client"),
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

              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: "Status"),
                items: const [
                  DropdownMenuItem(value: "Open", child: Text("Open")),
                  DropdownMenuItem(value: "Closed", child: Text("Closed")),
                ],
                onChanged: (value) => setState(() => status = value),
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
                onPressed: _updateClient,
                child: const Text(
                  "Update Client",
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