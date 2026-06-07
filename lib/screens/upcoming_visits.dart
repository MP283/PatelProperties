import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_visit.dart';
import 'edit_visits.dart';

class UpcomingVisitsPage extends StatefulWidget {
  const UpcomingVisitsPage({super.key});

  @override
  State<UpcomingVisitsPage> createState() => _UpcomingVisitsPageState();
}

class _UpcomingVisitsPageState extends State<UpcomingVisitsPage> {

  Future<String> _getClientName(String clientId) async {
    final doc = await FirebaseFirestore.instance.collection("clients").doc(clientId).get();
    return doc.exists ? (doc["clientName"] ?? clientId) : clientId;
  }

  Future<String> _getPropertyName(String propertyId) async {
    final doc = await FirebaseFirestore.instance.collection("properties").doc(propertyId).get();
    return doc.exists ? (doc["projectName"] ?? propertyId) : propertyId;
  }

  String formatTo12Hour(String time24) {
    if (time24.isEmpty) return "";
    final parts = time24.split(":");
    if (parts.length < 2) return time24;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;

    String period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final minuteStr = minute.toString().padLeft(2, '0');
    return "$hour:$minuteStr $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upcoming Visits"),
        backgroundColor: Colors.blueGrey.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("visits")
            .where("status", isEqualTo: "Not Completed")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No upcoming visits"));
          }

          final visits = snapshot.data!.docs;

          return ListView.builder(
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              final clientId = visit["clientId"] ?? "";
              final propertyId = visit["propertyId"] ?? "";

              return FutureBuilder(
                future: Future.wait([
                  _getClientName(clientId),
                  _getPropertyName(propertyId),
                ]),
                builder: (context, AsyncSnapshot<List<String>> namesSnapshot) {
                  if (!namesSnapshot.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }
                  final clientName = namesSnapshot.data![0];
                  final propertyName = namesSnapshot.data![1];

                  final date = visit["date"] ?? "";
                  final time = visit["time"] ?? "";
                  final remarks = visit["remarks"] ?? "";
                  final status = visit["status"] ?? "";

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.blueGrey),
                      title: Text(
                        "Client: $clientName",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Property: $propertyName\n"
                        "Date: $date • Time: ${formatTo12Hour(time)}",
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
                                Text("Date: $date"),
                                Text("Time: ${formatTo12Hour(time)}"),
                                Text("Remarks: $remarks"),
                                Text("Status: $status"),
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
                                      // Close the dialog first
                                      Navigator.of(context).pop();

                                      // Show snackbar immediately (safe, context still valid)
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Deleting visit...")),
                                      );

                                      try {
                                        await FirebaseFirestore.instance
                                            .collection("visits")
                                            .doc(visit.id)
                                            .delete();

                                        // Optionally navigate back one more step
                                        // if (mounted) {
                                        //   Navigator.of(this.context).maybePop();
                                        // }
                                      } catch (e) {
                                        // Show error message safely
                                        if (mounted) {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(content: Text("Error deleting visit: $e")),
                                          );
                                        }
                                      }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVisitPage()),
          );
        },
        backgroundColor: Colors.blueGrey.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
}