import 'package:flutter/material.dart';
import 'package:myapp/screens/parent/parent_dashboard_screen.dart';
import 'package:myapp/screens/parent/alerts_screen.dart';
import 'package:myapp/screens/parent/command_center_screen.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/parent/connect_screen.dart';
import 'package:myapp/screens/parent/parent_profile_screen.dart';
import 'package:myapp/widgets/parent/parent_custom_bottom_nav.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/screens/welcome_screen.dart';

class ParentMainLayout extends StatefulWidget {
  final String email;
  final String password;
  final String childHash;

  const ParentMainLayout({
    super.key,
    required this.email,
    required this.password,
    required this.childHash,
  });

  @override
  State<ParentMainLayout> createState() => _ParentMainLayoutState();
}

class _ParentMainLayoutState extends State<ParentMainLayout> {
  int _currentIndex = 2; // Default to Dashboard (center)

  // Placeholder screens for Parent
  List<Widget> get _screens => [
    ConnectScreen(
      onBack: () {
        setState(() {
          _currentIndex = 2; // Return to dashboard
        });
      },
    ),
    const AlertsScreen(),
    ParentDashboardScreen(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    ),
    CommandCenterScreen(
      onBack: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    ),
    ParentProfileScreen(
      email: widget.email,
      password: widget.password,
      onBack: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      onLogout: () async {
        await SessionService.clearParentSession();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      },
    ),
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
