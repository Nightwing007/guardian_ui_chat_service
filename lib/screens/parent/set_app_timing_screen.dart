import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/set_screen_time_bottom_sheet.dart';

class SetAppTimingScreen extends StatefulWidget {
  const SetAppTimingScreen({super.key});

  @override
  State<SetAppTimingScreen> createState() => _SetAppTimingScreenState();
}

class _SetAppTimingScreenState extends State<SetAppTimingScreen> {
  // Mock data for apps with their current time limits
  final List<Map<String, dynamic>> _apps = [
    {
      'name': 'Whats App',
      'icon': Icons.chat,
      'color': const Color(0xFF25D366),
      'limit': '6hr',
    },
    {
      'name': 'Instagram',
      'icon': Icons.camera_alt,
      'color': const Color(0xFFE1306C),
      'limit': '1hr',
    },
    {
      'name': 'Chrome',
      'icon': Icons.public,
      'color': const Color(0xFF4285F4),
      'limit': '6hr',
    },
    {
      'name': 'TikTok',
      'icon': Icons.music_note,
      'color': const Color(0xFF000000), // Black or dark grey
      'limit': '2hr',
    },
    {
      'name': 'YouTube',
      'icon': Icons.play_arrow,
      'color': const Color(0xFFFF0000),
      'limit': '3hr',
    },
    {
      'name': 'Snapchat',
      'icon': Icons.snapchat,
      'color': const Color(0xFFFFFC00),
      'limit': '1hr',
    },
    {
      'name': 'Facebook',
      'icon': Icons.facebook,
      'color': const Color(0xFF1877F2),
      'limit': '4hr',
    },
  ];

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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Set App Timing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // List of Apps
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final item = _apps[index];
                  // If it's Snapchat, icon is typically dark on yellow
                  final iconColor = item['name'] == 'Snapchat' ? Colors.black : Colors.white;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616), // Dark grey background
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        // App Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(item['icon'] as IconData, color: iconColor, size: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // App Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['limit'] as String,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Edit Button
                        GestureDetector(
                          onTap: () async {
                            final limitStr = item['limit'] as String;
                            int hours = 0;
                            if (limitStr.contains('hr')) {
                              hours = int.tryParse(limitStr.split('hr')[0].trim()) ?? 0;
                            }
                            
                            final newDuration = await showModalBottomSheet<Duration>(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => SetScreenTimeBottomSheet(
                                title: item['name'] as String,
                                initialDuration: Duration(hours: hours),
                              ),
                            );

                            if (newDuration != null) {
                              setState(() {
                                item['limit'] = '${newDuration.inHours}hr';
                              });
                            }
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.cmdIconBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Color(0xFF2B2B2B), size: 18),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
