import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_rent_agreement_page.dart';
import 'edit_rent_agreement_page.dart';

class RentAgreementsPage extends StatefulWidget {
  const RentAgreementsPage({super.key});

  @override
  State<RentAgreementsPage> createState() => _RentAgreementsPageState();
}

class _RentAgreementsPageState extends State<RentAgreementsPage> {
  String filterStatus = "All";
  final dateFormat = DateFormat("dd-MM-yyyy");

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Status Color ─────────────────────────────────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case "pending":
        return const Color(0xFFEF4444); // red
      case "done":
        return const Color(0xFF10B981); // green
      case "payment pending":
        return const Color(0xFFF59E0B); // amber
      case "submitted":
        return const Color(0xFF3B82F6); // blue
      case "not required":
        return const Color(0xFF8B5CF6); // purple
      default:
        return Colors.grey;
    }
  }

  // ─── Filter Logic ─────────────────────────────────────────────────────────

  bool _matchesFilter(Map<String, dynamic> data) {
    final status = data["status"] ?? "";

    // When "All" is selected, hide "not required" entries
    if (filterStatus == "All") {
      return status != "not required";
    }

    // When a specific status is selected, show only that status
    return status == filterStatus;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final owner = (data["ownerName"] ?? "").toString().toLowerCase();
    final tenant = (data["tenantName"] ?? "").toString().toLowerCase();
    final property = (data["propertyName"] ?? "").toString().toLowerCase();
    return owner.contains(query) ||
        tenant.contains(query) ||
        property.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rent Agreements"),
      ),
      body: Column(
        children: [
          // ── Filter + Search ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: filterStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Filter",
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  selectedItemBuilder: (context) {
                    return [
                      "All",
                      "pending",
                      "done",
                      "submitted",
                      "payment pending",
                      "not required",
                    ].map((s) {
                      if (s == "All") return const Text("All");
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(s).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _statusColor(s).withOpacity(0.4)),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(s),
                          ),
                        ),
                      );
                    }).toList();
                  },
                  items: [
                    "All",
                    "pending",
                    "done",
                    "submitted",
                    "payment pending",
                    "not required",
                  ].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: s == "All"
                          ? const Row(
                              children: [
                                Icon(Icons.all_inclusive,
                                    size: 14, color: Colors.grey),
                                SizedBox(width: 8),
                                Text("All"),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _statusColor(s),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(s),
                                if (s == "not required") ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    "(hidden by default)",
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => filterStatus = val);
                  },
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Search",
                    hintText: "Owner, Tenant, Property",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim()),
                ),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rentAgreements")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("Error loading agreements"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _matchesFilter(data) && _matchesSearch(data);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          filterStatus == "not required"
                              ? "No 'not required' agreements"
                              : "No agreements found",
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data["status"] as String?;

                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                            "${data["tokenNumber"]} - ${data["ownerName"]}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data["propertyName"] ?? ""),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _statusColor(status), width: 1),
                              ),
                              child: Text(
                                status ?? "",
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            final text = """
Token: ${data["tokenNumber"]}
Password: ${data["password"]}
Owner: ${data["ownerName"]} (${data["ownerPhone"]}, ${data["ownerEmail"]})
Tenant: ${data["tenantName"]} (${data["tenantPhone"]}, ${data["tenantEmail"]})
Property: ${data["propertyName"]}
""";
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Copied to clipboard")),
                            );
                          },
                        ),
                        onTap: () => _showDetails(context, data, doc.id),
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
            MaterialPageRoute(
                builder: (context) => const AddRentAgreementPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ─── Detail Dialog ────────────────────────────────────────────────────────

  void _showDetails(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final status = data["status"] as String?;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Flexible(
              child: Text(
                "${data["tokenNumber"]}",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor(status), width: 1),
              ),
              child: Text(
                status ?? "",
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Token Number", data["tokenNumber"] ?? ""),
              _detailRow("Password", data["password"] ?? ""),
              _detailRow("Owner Name", data["ownerName"] ?? ""),
              _detailRow("Tenant Name", data["tenantName"] ?? ""),
              _detailRow("Property Name", data["propertyName"] ?? ""),
              _detailRow("Stamp Duty", data["stampDuty"].toString()),
              _detailRow("Cost", data["cost"].toString()),
              _detailRow(
                  "Cost per Party", data["costPerParty"].toString()),
              _detailRow(
                  "Start Date",
                  data["startDate"] != null
                      ? dateFormat.format(
                          (data["startDate"] as Timestamp).toDate())
                      : "Not set"),
              _detailRow(
                  "Duration", "${data["durationMonths"]} months"),
              _detailRow(
                  "End Date",
                  data["endDate"] != null
                      ? dateFormat.format(
                          (data["endDate"] as Timestamp).toDate())
                      : "Not set"),
              _detailRow("Owner Phone", data["ownerPhone"] ?? ""),
              _detailRow("Tenant Phone", data["tenantPhone"] ?? ""),
              _detailRow("Owner Email", data["ownerEmail"] ?? ""),
              _detailRow("Tenant Email", data["tenantEmail"] ?? ""),
              _detailRow(
                  "Owner Charges Paid",
                  data["ownerChargesPaid"] == true ? "Paid" : "Not Paid"),
              _detailRow(
                  "Tenant Charges Paid",
                  data["tenantChargesPaid"] == true ? "Paid" : "Not Paid"),
              _detailRow("Status", data["status"] ?? ""),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRentAgreementPage(
                    docId: docId,
                    data: data,
                  ),
                ),
              );
            },
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection("rentAgreements")
                  .doc(docId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Agreement deleted")),
                );
              }
            },
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ─── Detail Row ───────────────────────────────────────────────────────────

  Widget _detailRow(String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$label copied")),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text("$label: ",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value)),
            const Icon(Icons.copy, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}