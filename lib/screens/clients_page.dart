import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_client.dart';
import 'client_visits_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String selectedDealType = "All"; // Buy/Rent/All
  String selectedPropertyType = "All"; // Residential/Commercial/Other/All
  String selectedStatus = "All"; // Open/Closed/All

  Future<void> _callClient(String number) async {
    final Uri telUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clients"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: Column(
        children: [
          // Filters row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: selectedDealType,
                    decoration: const InputDecoration(labelText: "Buy / Rent"),
                    items: const [
                      DropdownMenuItem(value: "Buy", child: Text("Buy")),
                      DropdownMenuItem(value: "Rent", child: Text("Rent")),
                      DropdownMenuItem(value: "All", child: Text("All")),
                    ],
                    onChanged: (value) => setState(() => selectedDealType = value!),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: selectedPropertyType,
                    decoration: const InputDecoration(labelText: "Type"),
                    items: const [
                      DropdownMenuItem(value: "Residential", child: Text("Residential")),
                      DropdownMenuItem(value: "Commercial", child: Text("Commercial")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                      DropdownMenuItem(value: "All", child: Text("All")),
                    ],
                    onChanged: (value) => setState(() => selectedPropertyType = value!),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: "Status"),
                    items: const [
                      DropdownMenuItem(value: "Open", child: Text("Open")),
                      DropdownMenuItem(value: "Closed", child: Text("Closed")),
                      DropdownMenuItem(value: "All", child: Text("All")),
                    ],
                    onChanged: (value) => setState(() => selectedStatus = value!),
                  ),
                ),
              ],
            ),
          ),

          // Client list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("clients")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No clients found"));
                }

                final docs = snapshot.data!.docs;

                // Apply filters
                final filteredDocs = docs.where((doc) {
                  final dealType = doc["dealType"] ?? "";
                  final propertyType = doc["propertyType"] ?? "";
                  final status = doc["status"] ?? "";
                  final matchesDeal = selectedDealType == "All" || dealType == selectedDealType;
                  final matchesType = selectedPropertyType == "All" || propertyType == selectedPropertyType;
                  final matchesStatus = selectedStatus == "All" || status == selectedStatus;
                  return matchesDeal && matchesType && matchesStatus;
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final client = filteredDocs[index];
                    final isOpen = (client["status"] ?? "") == "Open";
                    final isClosed = (client["status"] ?? "") == "Closed";

                    return Card(
                      color: isOpen
                          ? Colors.blue.shade100
                          : isClosed
                              ? Colors.green.shade100
                              : Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading: Icon(
                          client["dealType"] == "Buy" ? Icons.shopping_cart : Icons.key,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          client["clientName"] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${client["dealType"] ?? ""} • ${client["propertyType"] ?? ""} • Budget: ₹${client["budget"] ?? ""}",
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(client["clientName"] ?? "Client"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ClientVisitsPage(
                                            clientId: client.id,
                                            clientName: client["clientName"],
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey.shade700,
                                    ),
                                    child: const Text("View Visits", style: TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text("Deal: ${client["dealType"] ?? ""}", textAlign: TextAlign.center),
                                  Text("Type: ${client["propertyType"] ?? ""}", textAlign: TextAlign.center),
                                  Text("Status: ${client["status"] ?? ""}", textAlign: TextAlign.center),
                                  Text("Budget: ₹${client["budget"] ?? ""}", textAlign: TextAlign.center),
                                  Text("Areas: ${client["areas"] ?? ""}", textAlign: TextAlign.center),
                                  Text("Remarks: ${client["remarks"] ?? ""}", textAlign: TextAlign.center),
                                  TextButton(
                                    onPressed: () => _callClient(client["contactNumber"] ?? ""),
                                    child: Text(
                                      "Phone: ${client["contactNumber"] ?? ""}",
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Close"),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context); // close dialog first
                                        if (mounted) {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            const SnackBar(content: Text("Deleting client...")),
                                          );
                                        }
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection("clients")
                                              .doc(client.id)
                                              .delete();
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context).showSnackBar(
                                              const SnackBar(content: Text("Client deleted")),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context).showSnackBar(
                                              SnackBar(content: Text("Error deleting client: $e")),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditClientPage(clientId: client.id),
                                          ),
                                        );
                                      },
                                      child: const Text("Edit"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddClientPage()),
          );
        },
        backgroundColor: Colors.blueGrey.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}