import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final dateFormat = DateFormat("dd-MM-yyyy");

class EditRentAgreementPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditRentAgreementPage({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditRentAgreementPage> createState() => _EditRentAgreementPageState();
}

class _EditRentAgreementPageState extends State<EditRentAgreementPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController tokenController;
  late TextEditingController passwordController;
  late TextEditingController ownerController;
  late TextEditingController tenantController;
  late TextEditingController propertyController;
  late TextEditingController ownerEmailController;
  late TextEditingController tenantEmailController;
  late TextEditingController ownerPhoneController;
  late TextEditingController tenantPhoneController;
  late TextEditingController stampDutyController;
  late TextEditingController costController;
  late TextEditingController durationController;

  DateTime? startDate;
  late String status;
  late bool ownerChargesPaid;
  late bool tenantChargesPaid;

  @override
  void initState() {
    super.initState();
    final d = widget.data;

    tokenController = TextEditingController(text: d["tokenNumber"] ?? "");
    passwordController = TextEditingController(text: d["password"] ?? "@Ep786110");
    ownerController = TextEditingController(text: d["ownerName"] ?? "");
    tenantController = TextEditingController(text: d["tenantName"] ?? "");
    propertyController = TextEditingController(text: d["propertyName"] ?? "");
    ownerEmailController = TextEditingController(text: d["ownerEmail"] ?? "");
    tenantEmailController = TextEditingController(text: d["tenantEmail"] ?? "");
    ownerPhoneController = TextEditingController(text: d["ownerPhone"] ?? "");
    tenantPhoneController = TextEditingController(text: d["tenantPhone"] ?? "");
    stampDutyController = TextEditingController(
        text: d["stampDuty"] != null ? d["stampDuty"].toString() : "");
    costController = TextEditingController(
        text: d["cost"] != null ? d["cost"].toString() : "");
    durationController = TextEditingController(
        text: d["durationMonths"] != null ? d["durationMonths"].toString() : "");

    if (d["startDate"] != null) {
      startDate = (d["startDate"] as Timestamp).toDate();
    }

    status = d["status"] ?? "pending";
    ownerChargesPaid = d["ownerChargesPaid"] ?? false;   // ✅ pre-filled
    tenantChargesPaid = d["tenantChargesPaid"] ?? false; // ✅ pre-filled
  }

  @override
  void dispose() {
    tokenController.dispose();
    passwordController.dispose();
    ownerController.dispose();
    tenantController.dispose();
    propertyController.dispose();
    ownerEmailController.dispose();
    tenantEmailController.dispose();
    ownerPhoneController.dispose();
    tenantPhoneController.dispose();
    stampDutyController.dispose();
    costController.dispose();
    durationController.dispose();
    super.dispose();
  }

  Future<void> _updateAgreement() async {
    if (!_formKey.currentState!.validate()) return;

    final password = passwordController.text.trim().isEmpty
        ? "@Ep786110"
        : passwordController.text.trim();

    final durationText = durationController.text.trim();
    final costText = costController.text.trim();
    final stampDutyText = stampDutyController.text.trim();

    final durationMonths =
        durationText.isNotEmpty ? int.tryParse(durationText) ?? 0 : 0;
    final cost =
        costText.isNotEmpty ? double.tryParse(costText) ?? 0.0 : 0.0;
    final stampDuty =
        stampDutyText.isNotEmpty ? double.tryParse(stampDutyText) ?? 0.0 : 0.0;

    DateTime? endDate;
    if (startDate != null && durationMonths > 0) {
      endDate = DateTime(
        startDate!.year,
        startDate!.month + durationMonths,
        startDate!.day-1, // set end date to one day before the same date in the next month
      );
    }

    await FirebaseFirestore.instance
        .collection("rentAgreements")
        .doc(widget.docId)
        .update({
      "tokenNumber": tokenController.text.trim(),
      "password": password,
      "ownerName": ownerController.text.trim(),
      "tenantName": tenantController.text.trim(),
      "propertyName": propertyController.text.trim(),
      "ownerEmail": ownerEmailController.text.trim(),
      "tenantEmail": tenantEmailController.text.trim(),
      "ownerPhone": ownerPhoneController.text.trim(),
      "tenantPhone": tenantPhoneController.text.trim(),
      "stampDuty": stampDuty,
      "cost": cost,
      "costPerParty": cost > 0 ? cost / 2 : 0.0,
      "startDate": startDate,
      "durationMonths": durationMonths,
      "endDate": endDate,
      "ownerChargesPaid": ownerChargesPaid,   // ✅ updated
      "tenantChargesPaid": tenantChargesPaid, // ✅ updated
      "status": status,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Agreement updated")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Rent Agreement")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: tokenController,
                decoration: const InputDecoration(labelText: "Token Number *"),
                validator: (v) => v!.isEmpty ? "Token number is required" : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  hintText: "Default: @Ep786110",
                ),
              ),
              TextFormField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: "Owner Name"),
              ),
              TextFormField(
                controller: tenantController,
                decoration: const InputDecoration(labelText: "Tenant Name"),
              ),
              TextFormField(
                controller: propertyController,
                decoration: const InputDecoration(labelText: "Property Name"),
              ),
              TextFormField(
                controller: ownerEmailController,
                decoration: const InputDecoration(labelText: "Owner Email"),
              ),
              TextFormField(
                controller: tenantEmailController,
                decoration: const InputDecoration(labelText: "Tenant Email"),
              ),
              TextFormField(
                controller: ownerPhoneController,
                decoration: const InputDecoration(labelText: "Owner Phone"),
              ),
              TextFormField(
                controller: tenantPhoneController,
                decoration: const InputDecoration(labelText: "Tenant Phone"),
              ),
              TextFormField(
                controller: stampDutyController,
                decoration: const InputDecoration(labelText: "Stamp Duty"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: costController,
                decoration: const InputDecoration(labelText: "Cost"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(labelText: "Duration (months)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(startDate == null
                      ? "Start Date: Not selected"
                      : "Start Date: ${dateFormat.format(startDate!)}"),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                items: ["pending", "done", "submitted", "payment pending"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => status = val!),
                decoration: const InputDecoration(labelText: "Status"),
              ),
              const SizedBox(height: 8),

              // ✅ Owner Charges Paid toggle (pre-filled from existing data)
              SwitchListTile(
                title: const Text("Owner Charges Paid"),
                value: ownerChargesPaid,
                onChanged: (val) => setState(() => ownerChargesPaid = val),
              ),

              // ✅ Tenant Charges Paid toggle (pre-filled from existing data)
              SwitchListTile(
                title: const Text("Tenant Charges Paid"),
                value: tenantChargesPaid,
                onChanged: (val) => setState(() => tenantChargesPaid = val),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateAgreement,
                child: const Text("Update Agreement"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}