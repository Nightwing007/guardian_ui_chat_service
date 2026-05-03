import 'package:flutter/material.dart';
import 'package:myapp/screens/role_selection_screen.dart';
import 'package:myapp/theme/app_colors.dart';

class ParentMainLayout extends StatefulWidget {
  const ParentMainLayout({super.key});

  @override
  State<ParentMainLayout> createState() => _ParentMainLayoutState();
}

class _ParentMainLayoutState extends State<ParentMainLayout> {
  int _currentIndex = 0;

  // Placeholder screens for Parent
  final List<Widget> _screens = [
    const Center(child: Text("Parent Dashboard", style: TextStyle(color: Colors.white, fontSize: 24))),
    const Center(child: Text("Family Members", style: TextStyle(color: Colors.white, fontSize: 24))),
    const Center(child: Text("Alerts", style: TextStyle(color: Colors.white, fontSize: 24))),
    const Center(child: Text("Settings", style: TextStyle(color: Colors.white, fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent View'),
        backgroundColor: AppColors.navbarBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.navbarBackground,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: AppColors.iconGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: 'Family',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
