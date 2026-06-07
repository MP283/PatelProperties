import 'package:flutter/material.dart';
import 'package:patel_properties/screens/clients_page.dart';
import 'package:patel_properties/screens/upcoming_visits.dart';
import 'propertiespage.dart';
import 'rent_agreements_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Decide how many columns based on screen size
    final crossAxisCount = screenWidth > 800 ? 4 : 2;

    return Scaffold(
      body: Stack(
        children: [
          // Background image with 50% transparency
          Center(
            child: Opacity(
              opacity: 0.5,
              child: FractionallySizedBox(
                widthFactor: 0.9,
                heightFactor: 0.9,
                child: Image.asset(
                  'lib/assets/background.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Text(
                    "Dashboard",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 30),

                  // Buttons grid
                  Expanded(
                    child: Center(
                      child: GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1, // keep buttons square
                        children: [
                          _buildDashboardButton(
                            context,
                            title: "Properties",
                            icon: Icons.home_work,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PropertiesPage(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardButton(
                            context,
                            title: "Clients",
                            icon: Icons.people,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ClientsPage(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardButton(
                            context,
                            title: "Upcoming Visits",
                            icon: Icons.event,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const UpcomingVisitsPage(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardButton(
                            context,
                            title: "Rent Agreements",
                            icon: Icons.assignment,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RentAgreementsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}