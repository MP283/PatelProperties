import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_visits.dart';

class ClientVisitsPage extends StatelessWidget {
  final String clientId;
  final String clientName;

  const ClientVisitsPage({super.key, required this.clientId, required this.clientName});

  Future<String> _getPropertyName(String propertyId) async {
    final doc = await FirebaseFirestore.instance.collection("properties").doc(propertyId).get();
    return doc.exists ? (doc["projectName"] ?? propertyId) : propertyId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: Text("Visits for $clientName"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("visits")
            .where("clientId", isEqualTo: clientId) // ✅ filter by client
            //.orderBy("date")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No visits found for this client"));
          }

          final visits = snapshot.data!.docs;

          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              final propertyId = visit["propertyId"];

              return FutureBuilder(
                future: _getPropertyName(propertyId),
                builder: (context, AsyncSnapshot<String> propertySnapshot) {
                  if (!propertySnapshot.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }
                  final propertyName = propertySnapshot.data!;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(
                        visit["status"] == "Completed" ? Icons.check_circle : Icons.schedule,
                        color: visit["status"] == "Completed" ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        "Property: $propertyName",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Date: ${visit["date"] ?? ""} • Time: ${visit["time"] ?? ""}\n"
                        "Status: ${visit["status"] ?? ""}",
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Visit Details"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Client: $clientName"),
                                Text("Property: $propertyName"),
                                Text("Date: ${visit["date"] ?? ""}"),
                                Text("Time: ${visit["time"] ?? ""}"),
                                Text("Remarks: ${visit["remarks"] ?? ""}"),
                                Text("Status: ${visit["status"] ?? ""}"),
                                const SizedBox(height: 16),
                              ],
                            ),
                            actions: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditVisitPage(visitId: visit.id),
                                        ),
                                      );
                                    },
                                    child: const Text("Edit"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection("visits")
                                          .doc(visit.id)
                                          .delete();
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Visit deleted")),
                                      );
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Close"),
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
          );
        },
      ),
    );
  }
}