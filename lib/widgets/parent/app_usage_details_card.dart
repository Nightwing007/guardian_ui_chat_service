import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myapp/widgets/parent/app_usage_item.dart';

class AppUsageDetailsCard extends StatelessWidget {
  const AppUsageDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Usage Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111), // Very dark background like the screenshot
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              AppUsageItem(
                icon: const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFE1306C), size: 24),
                appName: 'Instagram',
                category: 'Entertainment',
                usageTime: '45 mins',
                percentage: 60,
              ),
              AppUsageItem(
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24),
                appName: 'Whatsapp',
                category: 'Chatting App',
                usageTime: '45 mins',
                percentage: 60,
              ),
              AppUsageItem(
                icon: const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2), size: 24),
                appName: 'Facebook',
                category: 'Chatting App',
                usageTime: '45 mins',
                percentage: 60,
              ),
              AppUsageItem(
                icon: const FaIcon(FontAwesomeIcons.telegram, color: Color(0xFF0088CC), size: 24),
                appName: 'Messenger',
                category: 'Job Portal',
                usageTime: '45 mins',
                percentage: 60,
              ),
              AppUsageItem(
                icon: const FaIcon(FontAwesomeIcons.youtube, color: Color(0xFFFF0000), size: 20),
                appName: 'YouTube',
                category: 'Entertainment',
                usageTime: '45 mins',
                percentage: 60,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
