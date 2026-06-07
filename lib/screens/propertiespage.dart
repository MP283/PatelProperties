import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_property.dart';
import 'edit_property.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertiesPage extends StatefulWidget {
  const PropertiesPage({super.key});

  @override
  State<PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends State<PropertiesPage> {
  String selectedFilter = "All";
  String selectedType = "All";

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

  Future<void> _copyList(
      List<QueryDocumentSnapshot> docs, String type, String sellOrRent) async {
    final filtered = docs.where((doc) {
      final docType = doc["propertyType"] ?? "";
      final docSellOrRent = doc["sellOrRent"] ?? "";
      return docType == type && docSellOrRent == sellOrRent;
    }).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No $type $sellOrRent properties found")),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("🚨 $type - $sellOrRent 🚨");
    buffer.writeln("───────────────");

    for (int i = 0; i < filtered.length; i++) {
      final p = filtered[i];
      final name = p["projectName"] ?? "";
      final price = p["price"] ?? "";

      if (type == "Residential") {
        final bhk = p["bhk"] ?? "";
        buffer.writeln("${i + 1}. $name | $bhk BHK | ₹$price");
      } else {
        buffer.writeln("${i + 1}. $name | ₹$price");
      }
    }

    buffer.writeln("───────────────");
    buffer.writeln("CONTACT:");
    buffer.writeln("+91 8530815553");
    buffer.writeln("+91 9561354956");

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("$type $sellOrRent list copied (${filtered.length} items)")),
      );
    }
  }

  void _shareProperty(QueryDocumentSnapshot property) {
    final name = property["projectName"] ?? "";
    final bhk = property["bhk"] ?? "";
    final price = property["price"] ?? "";
    final sellOrRent = property["sellOrRent"] ?? "";
    final type = property["propertyType"] ?? "";

    final text = type == "Residential"
        ? "🏠 $name\n$bhk BHK\n₹$price\n$sellOrRent"
        : "🏢 $name\n₹$price\n$sellOrRent";

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Property details copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Properties"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      // ✅ No floatingActionButton here — moved inside body above the 4 buttons
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("properties")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final allDocs =
              snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

          return Column(
            children: [
              // Filters row
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedFilter,
                        decoration: InputDecoration(
                          labelText: "Sell / Rent",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: "Sell", child: Text("Sell")),
                          DropdownMenuItem(value: "Rent", child: Text("Rent")),
                          DropdownMenuItem(value: "All", child: Text("All")),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedFilter = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          labelText: "Type",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: "Residential", child: Text("Residential")),
                          DropdownMenuItem(
                              value: "Commercial", child: Text("Commercial")),
                          DropdownMenuItem(
                              value: "Other", child: Text("Other")),
                          DropdownMenuItem(value: "All", child: Text("All")),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedType = value!),
                      ),
                    ),
                  ],
                ),
              ),

              // Property list
              Expanded(
                child: Builder(builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (allDocs.isEmpty) {
                    return const Center(child: Text("No properties found"));
                  }

                  final filteredDocs = allDocs.where((doc) {
                    final sellOrRent = doc["sellOrRent"] ?? "";
                    final type = doc["propertyType"] ?? "";
                    final matchesFilter =
                        selectedFilter == "All" || sellOrRent == selectedFilter;
                    final matchesType =
                        selectedType == "All" || type == selectedType;
                    return matchesFilter && matchesType;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text("No properties found"));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final property = filteredDocs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: ListTile(
                          leading: Icon(
                            property["sellOrRent"] == "Sell"
                                ? Icons.sell
                                : Icons.key,
                            color: Colors.blueGrey,
                          ),
                          title: Text(property["projectName"] ?? ""),
                          subtitle: Text(
                            "${property["bhk"] ?? ""} BHK • ₹${property["price"] ?? ""}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.share, color: Colors.blueGrey),
                            onPressed: () => _shareProperty(property),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        property["projectName"] ?? "Property",
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share,
                                          color: Colors.blueGrey),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _shareProperty(property);
                                      },
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                        "Sell/Rent: ${property["sellOrRent"] ?? ""}",
                                        textAlign: TextAlign.center),
                                    Text(
                                        "Type: ${property["propertyType"] ?? ""}",
                                        textAlign: TextAlign.center),
                                    Text("BHK: ${property["bhk"] ?? ""}",
                                        textAlign: TextAlign.center),
                                    Text(
                                      "Price: ₹${property["price"] ?? ""}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                        "Owner: ${property["ownerName"] ?? ""}",
                                        textAlign: TextAlign.center),
                                    TextButton(
                                      onPressed: () => _callClient(
                                          property["ownerNumber"] ?? ""),
                                      child: Text(
                                        "Owner Number: ${property["ownerNumber"] ?? ""}",
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Text("Keys: ${property["keys"] ?? ""}",
                                        textAlign: TextAlign.center),
                                  ],
                                ),
                                actionsAlignment: MainAxisAlignment.center,
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Close"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      Navigator.pop(context);
                                      messenger.showSnackBar(const SnackBar(
                                          content:
                                              Text("Deleting property...")));
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection("properties")
                                            .doc(property.id)
                                            .delete();
                                        if (!mounted) return;
                                        messenger.showSnackBar(const SnackBar(
                                            content:
                                                Text("Property deleted")));
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(SnackBar(
                                            content: Text(
                                                "Error deleting property: $e")));
                                      }
                                    },
                                    child: const Text("Delete",
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditPropertyPage(
                                              propertyId: property.id),
                                        ),
                                      );
                                    },
                                    child: const Text("Edit"),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                }),
              ),

              // ✅ FAB sits just above the 4 buttons, aligned to the right
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddPropertyPage()),
                      );
                    },
                    backgroundColor: Colors.blueGrey.shade700,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),

              // ✅ 4 quick copy buttons — no background, no border
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _quickCopyButton(
                      label: "RR",
                      tooltip: "Residential Rent",
                      color: Colors.teal,
                      icon: Icons.home,
                      onTap: () => _copyList(allDocs, "Residential", "Rent"),
                    ),
                    _quickCopyButton(
                      label: "RS",
                      tooltip: "Residential Sale",
                      color: Colors.indigo,
                      icon: Icons.home,
                      onTap: () => _copyList(allDocs, "Residential", "Sell"),
                    ),
                    _quickCopyButton(
                      label: "CR",
                      tooltip: "Commercial Rent",
                      color: Colors.orange,
                      icon: Icons.business,
                      onTap: () => _copyList(allDocs, "Commercial", "Rent"),
                    ),
                    _quickCopyButton(
                      label: "CS",
                      tooltip: "Commercial Sale",
                      color: Colors.red,
                      icon: Icons.business,
                      onTap: () => _copyList(allDocs, "Commercial", "Sell"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickCopyButton({
    required String label,
    required String tooltip,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}