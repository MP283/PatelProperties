import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final dateFormat = DateFormat("dd-MM-yyyy");

// ─── Status Color Helper ──────────────────────────────────────────────────────

Color getStatusColor(String status) {
  switch (status) {
    case 'done':
      return const Color(0xFF10B981); // green
    case 'submitted':
      return const Color(0xFF3B82F6); // blue
    case 'payment pending':
      return const Color(0xFFF59E0B); // amber
    case 'not required':
      return const Color(0xFF8B5CF6); // purple
    case 'pending':
    default:
      return const Color(0xFFEF4444); // red
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AddRentAgreementPage extends StatefulWidget {
  const AddRentAgreementPage({super.key});

  @override
  State<AddRentAgreementPage> createState() => _AddRentAgreementPageState();
}

class _AddRentAgreementPageState extends State<AddRentAgreementPage> {
  final _formKey = GlobalKey<FormState>();

  final tokenController = TextEditingController();
  final passwordController = TextEditingController(text: "@Ep786110");
  final ownerController = TextEditingController();
  final tenantController = TextEditingController();
  final propertyController = TextEditingController();
  final ownerEmailController = TextEditingController();
  final tenantEmailController = TextEditingController();
  final ownerPhoneController = TextEditingController();
  final tenantPhoneController = TextEditingController();
  final stampDutyController = TextEditingController();
  final costController = TextEditingController();
  final durationController = TextEditingController();
  DateTime? startDate;

  String status = "pending";
  bool ownerChargesPaid = false;
  bool tenantChargesPaid = false;

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

  Future<void> _saveAgreement() async {
    if (!_formKey.currentState!.validate()) return;

    final token = tokenController.text.trim();
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
        startDate!.day - 1,
      );
    }

    // Save as UTC midnight to avoid timezone shift in Google Sheets
    final utcStartDate = startDate != null
        ? DateTime.utc(startDate!.year, startDate!.month, startDate!.day)
        : null;
    final utcEndDate = endDate != null
        ? DateTime.utc(endDate.year, endDate.month, endDate.day)
        : null;

    await FirebaseFirestore.instance.collection("rentAgreements").add({
      "tokenNumber": token,
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
      "startDate": utcStartDate,
      "durationMonths": durationMonths,
      "endDate": utcEndDate,
      "ownerChargesPaid": ownerChargesPaid,
      "tenantChargesPaid": tenantChargesPaid,
      "status": status,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agreement saved")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Rent Agreement")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: "Token Number *",
                  hintText: "Required",
                ),
                validator: (v) =>
                    v!.isEmpty ? "Token number is required" : null,
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
                decoration:
                    const InputDecoration(labelText: "Property Name"),
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
                decoration:
                    const InputDecoration(labelText: "Duration (months)"),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              // ── Start Date Picker ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        startDate == null
                            ? "Start Date: Not selected"
                            : "Start Date: ${dateFormat.format(startDate!)}",
                        style: TextStyle(
                          fontSize: 14,
                          color: startDate == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
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
              ),

              const SizedBox(height: 16),

              // ── Status Dropdown with colors ──
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: "Status"),
                selectedItemBuilder: (context) {
                  return [
                    "pending",
                    "done",
                    "submitted",
                    "payment pending",
                    "not required"
                  ].map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: getStatusColor(s).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: getStatusColor(s).withOpacity(0.4)),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(s),
                        ),
                      ),
                    );
                  }).toList();
                },
                items: [
                  "pending",
                  "done",
                  "submitted",
                  "payment pending",
                  "not required"
                ]
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: getStatusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(s),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => status = val!),
              ),

              const SizedBox(height: 8),

              // ── Owner Charges Paid ──
              SwitchListTile(
                title: const Text("Owner Charges Paid"),
                value: ownerChargesPaid,
                onChanged: (val) => setState(() => ownerChargesPaid = val),
              ),

              // ── Tenant Charges Paid ──
              SwitchListTile(
                title: const Text("Tenant Charges Paid"),
                value: tenantChargesPaid,
                onChanged: (val) => setState(() => tenantChargesPaid = val),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveAgreement,
                child: const Text("Save Agreement"),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}