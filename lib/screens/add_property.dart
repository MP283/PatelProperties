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
  String? keysOption = "Direct";
  bool _viaSecondBroker = false; // ← new

  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController unitNoController = TextEditingController();
  final TextEditingController bhkController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerNumberController = TextEditingController();
  final TextEditingController brokerNameController = TextEditingController();
  final TextEditingController secondBrokerNameController = TextEditingController(); // ← new

  @override
  void dispose() {
    projectNameController.dispose();
    unitNoController.dispose();
    bhkController.dispose();
    priceController.dispose();
    ownerNameController.dispose();
    ownerNumberController.dispose();
    brokerNameController.dispose();
    secondBrokerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCommercial = propertyType == "Commercial";
    final bool withBroker = keysOption == "With Broker";

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
              // Sell / Rent
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

              // Property Type
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

              // Project Name
              TextFormField(
                controller: projectNameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (value) =>
                    value!.isEmpty ? "Please enter project name" : null,
              ),
              const SizedBox(height: 16),

              // Unit No.
              TextFormField(
                controller: unitNoController,
                decoration: const InputDecoration(labelText: "Unit No."),
              ),
              const SizedBox(height: 16),

              // BHK / Sq. Ft.
              TextFormField(
                controller: bhkController,
                decoration: InputDecoration(
                  labelText: isCommercial ? "Sq. Ft." : "BHK",
                ),
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

              // Keys — Direct or With Broker
              DropdownButtonFormField<String>(
                value: keysOption,
                decoration: const InputDecoration(labelText: "Keys"),
                items: const [
                  DropdownMenuItem(value: "Direct", child: Text("Direct")),
                  DropdownMenuItem(value: "With Broker", child: Text("With Broker")),
                ],
                onChanged: (value) {
                  setState(() {
                    keysOption = value;
                    if (value != "With Broker") brokerNameController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Broker Name for keys — only when "With Broker"
              if (withBroker) ...[
                TextFormField(
                  controller: brokerNameController,
                  decoration: const InputDecoration(labelText: "Broker Name (Keys)"),
                  validator: (value) =>
                      value!.isEmpty ? "Please enter broker name" : null,
                ),
                const SizedBox(height: 16),
              ],

              // ── Via Second Broker toggle ───────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _viaSecondBroker
                      ? Colors.orange.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _viaSecondBroker
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      color: _viaSecondBroker
                          ? Colors.orange.shade700
                          : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Via Second Broker",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _viaSecondBroker
                                  ? Colors.orange.shade800
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            "Property sourced through another broker",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _viaSecondBroker,
                      activeColor: Colors.orange.shade700,
                      onChanged: (val) {
                        setState(() {
                          _viaSecondBroker = val;
                          if (!val) secondBrokerNameController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Second broker name — shown only when toggle is on
              if (_viaSecondBroker) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: secondBrokerNameController,
                  decoration: InputDecoration(
                    labelText: "Second Broker Name",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => _viaSecondBroker && (value == null || value.trim().isEmpty)
                      ? "Please enter the second broker's name"
                      : null,
                ),
              ],
              // ─────────────────────────────────────────────────────────────

              const SizedBox(height: 24),

              // Submit
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await FirebaseFirestore.instance
                        .collection("properties")
                        .add({
                      "sellOrRent": sellOrRent,
                      "propertyType": propertyType,
                      "projectName": projectNameController.text,
                      "unitNo": unitNoController.text,
                      "bhkOrSqft": bhkController.text,
                      "bhkLabel": isCommercial ? "sqft" : "bhk",
                      "price": priceController.text,
                      "ownerName": ownerNameController.text,
                      "ownerNumber": ownerNumberController.text,
                      "keys": keysOption,
                      if (withBroker)
                        "brokerName": brokerNameController.text,
                      // Second broker fields — always written so reads never throw
                      "viaSecondBroker": _viaSecondBroker,
                      "secondBrokerName": _viaSecondBroker
                          ? secondBrokerNameController.text.trim()
                          : "",
                      "createdAt": DateTime.now(),
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Property added successfully!")),
                      );
                      Navigator.pop(context);
                    }
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