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
  String selectedBhk = "All";
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _field(QueryDocumentSnapshot doc, String key, {String fallback = ""}) {
    final data = doc.data() as Map<String, dynamic>;
    return (data[key] ?? fallback).toString();
  }

  String _bhkValue(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return (data['bhkOrSqft'] ?? data['bhk'] ?? '').toString();
  }

  String _bhkLabel(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final label = (data['bhkLabel'] ?? 'bhk').toString();
    return label == 'sqft' ? 'Sq. Ft.' : 'BHK';
  }

  // Keys tab — who physically holds the keys
  bool _isWithBroker(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return (data['keys'] ?? '').toString().toLowerCase() == 'with broker';
  }

  // Sourcing — property came via another broker (new toggle from add_property)
  bool _isViaSecondBroker(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return (data['viaSecondBroker'] ?? false) == true;
  }

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

  // Excludes: keys "With Broker" AND sourced via second broker
  Future<void> _copyList(
      List<QueryDocumentSnapshot> docs, String type, String sellOrRent) async {
    final filtered = docs.where((doc) {
      final docType = _field(doc, 'propertyType');
      final docSellOrRent = _field(doc, 'sellOrRent');
      final viaSecondBroker = _isViaSecondBroker(doc);
      return docType == type &&
          docSellOrRent == sellOrRent &&
          !viaSecondBroker;
    }).toList();

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("No $type $sellOrRent properties with us found")),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("🚨 $type - $sellOrRent 🚨");
    buffer.writeln("───────────────");

    for (int i = 0; i < filtered.length; i++) {
      final p = filtered[i];
      final name = _field(p, 'projectName');
      final price = _field(p, 'price');
      final bhk = _bhkValue(p);
      final label = _bhkLabel(p);

      if (type == "Residential" && bhk.isNotEmpty) {
        buffer.writeln("${i + 1}. $name | $bhk $label | ₹$price");
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
            content: Text(
                "$type $sellOrRent list copied (${filtered.length} items)")),
      );
    }
  }

  void _shareProperty(QueryDocumentSnapshot property) {
    final name = _field(property, 'projectName');
    final bhk = _bhkValue(property);
    final label = _bhkLabel(property);
    final price = _field(property, 'price');
    final sellOrRent = _field(property, 'sellOrRent');
    final type = _field(property, 'propertyType');

    final text = (type == "Residential" && bhk.isNotEmpty)
        ? "🏠 $name\n$bhk $label\n₹$price\n$sellOrRent"
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("properties")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final allDocs = snapshot.hasData
              ? snapshot.data!.docs
              : <QueryDocumentSnapshot>[];

          final bhkSet = <String>{};
          for (final doc in allDocs) {
            final type = _field(doc, 'propertyType');
            if (type == "Residential") {
              final val = _bhkValue(doc);
              if (val.isNotEmpty) bhkSet.add(val);
            }
          }
          final bhkOptions = ['All', ...bhkSet.toList()..sort()];

          return Column(
            children: [
              // ── Search bar ───────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search by project, unit no. or owner...",
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),

              // ── Filters row ──────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedFilter,
                        decoration: InputDecoration(
                          labelText: "Sell / Rent",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: "All", child: Text("All")),
                          DropdownMenuItem(value: "Sell", child: Text("Sell")),
                          DropdownMenuItem(value: "Rent", child: Text("Rent")),
                        ],
                        onChanged: (v) =>
                            setState(() => selectedFilter = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: "Type",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: "All", child: Text("All")),
                          DropdownMenuItem(
                              value: "Residential",
                              child: Text("Residential")),
                          DropdownMenuItem(
                              value: "Commercial",
                              child: Text("Commercial")),
                          DropdownMenuItem(
                              value: "Others", child: Text("Others")),
                        ],
                        onChanged: (v) {
                          setState(() {
                            selectedType = v!;
                            if (v != "Residential") selectedBhk = "All";
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectedType == "Residential" ||
                        selectedType == "All") ...[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: bhkOptions.contains(selectedBhk)
                              ? selectedBhk
                              : "All",
                          decoration: InputDecoration(
                            labelText: "BHK",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          items: bhkOptions
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => selectedBhk = v!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Property list ────────────────────────────────────────────
              Expanded(
                child: Builder(builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (allDocs.isEmpty) {
                    return const Center(child: Text("No properties found"));
                  }

                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final sellOrRent =
                        (data['sellOrRent'] ?? '').toString();
                    final type =
                        (data['propertyType'] ?? '').toString();
                    final bhk = _bhkValue(doc);

                    final matchesFilter = selectedFilter == "All" ||
                        sellOrRent == selectedFilter;
                    final matchesType =
                        selectedType == "All" || type == selectedType;
                    final matchesBhk = selectedBhk == "All" ||
                        (type == "Residential" && bhk == selectedBhk);

                    final projectName = (data['projectName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final unitNo =
                        (data['unitNo'] ?? '').toString().toLowerCase();
                    final ownerName =
                        (data['ownerName'] ?? '').toString().toLowerCase();
                    final matchesSearch = _searchQuery.isEmpty ||
                        projectName.contains(_searchQuery) ||
                        unitNo.contains(_searchQuery) ||
                        ownerName.contains(_searchQuery);

                    return matchesFilter &&
                        matchesType &&
                        matchesBhk &&
                        matchesSearch;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text("No properties found"));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final property = filteredDocs[index];
                      final data =
                          property.data() as Map<String, dynamic>;
                      final type =
                          (data['propertyType'] ?? '').toString();
                      final bhk = _bhkValue(property);
                      final bhkLabelStr = _bhkLabel(property);
                      final projectName =
                          (data['projectName'] ?? '').toString();
                      final unitNo =
                          (data['unitNo'] ?? '').toString();
                      final price = (data['price'] ?? '').toString();
                      final keysWithBroker = _isWithBroker(property);
                      final viaSecondBroker = _isViaSecondBroker(property);

                      String subtitle = '';
                      if (bhk.isNotEmpty) {
                        subtitle = '$bhk $bhkLabelStr • ₹$price';
                      } else {
                        subtitle = '₹$price';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ListTile(
                          leading: Icon(
                            _field(property, 'sellOrRent') == "Sell"
                                ? Icons.sell
                                : Icons.key,
                            color: Colors.blueGrey,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  unitNo.isNotEmpty
                                      ? '$projectName • $unitNo'
                                      : projectName,
                                ),
                              ),
                              // Keys "With Broker" badge — purple
                              if (keysWithBroker)
                                _badge(
                                  label: "Keys: Broker",
                                  color: Colors.purple,
                                ),
                              if (keysWithBroker && viaSecondBroker)
                                const SizedBox(width: 4),
                              // Via second broker badge — orange
                              if (viaSecondBroker)
                                _badge(
                                  label: "2nd Broker",
                                  color: Colors.orange,
                                ),
                            ],
                          ),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.share,
                                color: Colors.blueGrey),
                            onPressed: () => _shareProperty(property),
                          ),
                          onTap: () =>
                              _showPropertyDetail(context, property),
                        ),
                      );
                    },
                  );
                }),
              ),

              // ── FAB ──────────────────────────────────────────────────────
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

              // ── 4 quick copy buttons ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _quickCopyButton(
                      label: "RR",
                      tooltip: "Residential Rent (ours only)",
                      color: Colors.teal,
                      icon: Icons.home,
                      onTap: () =>
                          _copyList(allDocs, "Residential", "Rent"),
                    ),
                    _quickCopyButton(
                      label: "RS",
                      tooltip: "Residential Sale (ours only)",
                      color: Colors.indigo,
                      icon: Icons.home,
                      onTap: () =>
                          _copyList(allDocs, "Residential", "Sell"),
                    ),
                    _quickCopyButton(
                      label: "CR",
                      tooltip: "Commercial Rent (ours only)",
                      color: Colors.orange,
                      icon: Icons.business,
                      onTap: () =>
                          _copyList(allDocs, "Commercial", "Rent"),
                    ),
                    _quickCopyButton(
                      label: "CS",
                      tooltip: "Commercial Sale (ours only)",
                      color: Colors.red,
                      icon: Icons.business,
                      onTap: () =>
                          _copyList(allDocs, "Commercial", "Sell"),
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

  // Reusable badge widget
  Widget _badge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showPropertyDetail(
      BuildContext context, QueryDocumentSnapshot property) {
    final data = property.data() as Map<String, dynamic>;
    final bhk = _bhkValue(property);
    final bhkLabelStr = _bhkLabel(property);
    final type = (data['propertyType'] ?? '').toString();
    final unitNo = (data['unitNo'] ?? '').toString();
    final keysWithBroker = _isWithBroker(property);
    final viaSecondBroker = _isViaSecondBroker(property);
    final brokerName = (data['brokerName'] ?? '').toString();
    final secondBrokerName = (data['secondBrokerName'] ?? '').toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                (data['projectName'] ?? 'Property').toString(),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.blueGrey),
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
            if (unitNo.isNotEmpty)
              Text("Unit No.: $unitNo", textAlign: TextAlign.center),
            Text("Sell/Rent: ${(data['sellOrRent'] ?? '').toString()}",
                textAlign: TextAlign.center),
            Text("Type: $type", textAlign: TextAlign.center),
            if (bhk.isNotEmpty)
              Text("$bhkLabelStr: $bhk", textAlign: TextAlign.center),
            Text(
              "Price: ₹${(data['price'] ?? '').toString()}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Owner: ${(data['ownerName'] ?? '').toString()}",
                textAlign: TextAlign.center),
            TextButton(
              onPressed: () =>
                  _callClient((data['ownerNumber'] ?? '').toString()),
              child: Text(
                "Owner Number: ${(data['ownerNumber'] ?? '').toString()}",
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              "Keys: ${keysWithBroker ? 'With Broker' : (data['keys'] ?? '').toString()}",
              textAlign: TextAlign.center,
            ),
            if (keysWithBroker && brokerName.isNotEmpty)
              Text(
                "Keys Broker: $brokerName",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.purple),
              ),
            // Via second broker info
            if (viaSecondBroker) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handshake_outlined,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          "Via Second Broker",
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (secondBrokerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondBrokerName,
                        style: TextStyle(
                            color: Colors.orange.shade700, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              messenger.showSnackBar(
                  const SnackBar(content: Text("Deleting property...")));
              try {
                await FirebaseFirestore.instance
                    .collection("properties")
                    .doc(property.id)
                    .delete();
                if (!mounted) return;
                messenger.showSnackBar(
                    const SnackBar(content: Text("Property deleted")));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                    SnackBar(content: Text("Error deleting: $e")));
              }
            },
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditPropertyPage(propertyId: property.id),
                ),
              );
            },
            child: const Text("Edit"),
          ),
        ],
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
