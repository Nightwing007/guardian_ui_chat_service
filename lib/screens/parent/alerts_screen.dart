import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/alert_card.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Text(
                    'Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // List of Alerts
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: const [
                  AlertCard(
                    source: 'Instagram',
                    sourceColor: Color(0xFFE1306C), // Pinkish
                    icon: Icons.emergency,
                    timeAgo: 'now',
                    title: 'Grooming Threat detected',
                    description: 'An unknown source is trying to groom the child into believing them.',
                  ),
                  AlertCard(
                    source: 'Snapchat',
                    sourceColor: Color(0xFFE1306C), // Pinkish red
                    icon: Icons.emergency,
                    timeAgo: '5 mins ago',
                    title: 'Cyberbullying detected',
                    description: 'aggressive language&threats from "Jake_09"',
                  ),
                  AlertCard(
                    source: 'System',
                    sourceColor: Color(0xFF4285F4), // Blue
                    icon: Icons.lightbulb_outline,
                    timeAgo: '2 hours ago',
                    title: 'Behavioral Change Detected',
                    description: 'unusual behavior has been noticed',
                  ),
                  AlertCard(
                    source: 'Chrome',
                    sourceColor: Color(0xFFEA4335), // Red
                    icon: Icons.report_problem,
                    timeAgo: '3 hrs ago',
                    title: 'Adult Content Blocked',
                    description: 'displaying an image flagged as Inappropriate',
                  ),
                  AlertCard(
                    source: 'System',
                    sourceColor: Color(0xFF4285F4), // Blue
                    icon: Icons.lightbulb_outline,
                    timeAgo: '5 hrs ago',
                    title: 'Screen Time Spike',
                    description: 'Daily usage limit exceeded by 300% compared to the weekly average.',
                  ),
                ],
              ),
            ),
            
            // Bottom padding for nav bar
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
