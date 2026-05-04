import 'package:flutter/material.dart';
import 'package:myapp/screens/parent/parent_dashboard_screen.dart';
import 'package:myapp/screens/parent/command_center_screen.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/parent_custom_bottom_nav.dart';

class ParentMainLayout extends StatefulWidget {
  const ParentMainLayout({super.key});

  @override
  State<ParentMainLayout> createState() => _ParentMainLayoutState();
}

class _ParentMainLayoutState extends State<ParentMainLayout> {
  int _currentIndex = 2; // Default to Dashboard (center)

  // Placeholder screens for Parent
  List<Widget> get _screens => [
    const Center(child: Text("Messages", style: TextStyle(color: Colors.white, fontSize: 24))),
    const Center(child: Text("Alerts", style: TextStyle(color: Colors.white, fontSize: 24))),
    const ParentDashboardScreen(),
    CommandCenterScreen(
      onBack: () {
        setState(() {
          _currentIndex = 2; // Return to dashboard
        });
      },
    ),
    const Center(child: Text("Profile", style: TextStyle(color: Colors.white, fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          _screens[_currentIndex],
          
          // Custom Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ParentCustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
          
        ],
      ),
    );
  }
}
