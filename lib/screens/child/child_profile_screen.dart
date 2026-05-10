import 'package:flutter/material.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/theme/app_colors.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final _db = AppDatabase();
  String _childName = 'Child';
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _db.child.getChildProfile();
    final childName = await _db.child.getChildDisplayName();
    if (!mounted) return;
    setState(() {
      _childName = childName;
      _profileImage = profile?['profile_image']?.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _profileImageUrl(_profileImage);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top section with curved background and avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Curved background
                ClipPath(
                  clipper: _TopCurveClipper(),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGradientStart,
                          AppColors.primaryGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Time & Battery (Fake StatusBar) - optional, the app might already have a transparent status bar, so let's just add some padding at top if needed.
                // Avatar
                Positioned(
                  bottom: 10,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF010304), // Scaffold background
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: Color(
                            0xFFE8AEB7,
                          ), // Light pinkish background for avatar
                          // Using a network image as placeholder to match the provided screenshot
                          backgroundImage: imageUrl == null
                              ? null
                              : NetworkImage(imageUrl),
                          child: imageUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 50,
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.transparent,
                                  size: 50,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3246),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF010304),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              _childName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, color: Colors.grey.shade400, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Connected with Parent',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Safety Settings Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryGradientStart,
                      AppColors.primaryGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAFETY SETTINGS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSettingRow(
                      icon: Icons.location_on_outlined,
                      title: 'Location Sharing',
                      subtitle: 'Real-time update',
                      badgeText: 'ON',
                      badgeColor: const Color(0xFFB5C9FF),
                      badgeTextColor: const Color(0xFF1E3A8A),
                    ),
                    const SizedBox(height: 20),
                    _buildSettingRow(
                      icon: Icons.language,
                      title: 'Browsing Protection',
                      subtitle: 'Filter enabled',
                      badgeText: 'ACTIVE',
                      badgeColor: const Color(0xFF2A2846),
                      badgeTextColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    _buildSettingRow(
                      icon: Icons.phone_android,
                      title: 'Guardian AI',
                      subtitle: 'Device protection enabled',
                      badgeText: 'ACTIVE',
                      badgeColor: const Color(0xFF2A2846),
                      badgeTextColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    _buildSettingRow(
                      icon: Icons.emergency,
                      title: 'SOS Access',
                      subtitle: 'Quick emergency key',
                      badgeText: 'ENABLED',
                      badgeColor: const Color(0xFF4A2525), // dark red bg
                      badgeTextColor: const Color(0xFFFF5252), // red text
                      iconBgColor: const Color(0xFFFFE5E5),
                      iconColor: const Color(0xFFFF5252),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bottom links card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryGradientStart,
                      AppColors.primaryGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _buildLinkRow(
                      icon: Icons.help_outline,
                      title: 'Why this app helps me stay safe',
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _buildLinkRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy information',
                    ),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _buildLinkRow(
                      icon: Icons.support_agent,
                      title: 'Help & Support',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120), // padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    Color? iconBgColor,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor ?? const Color(0xFFB5C9FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: iconColor ?? const Color(0xFF1E3A8A),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow({required IconData icon, required String title}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
      onTap: () {},
    );
  }

  String? _profileImageUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${AuthService.baseUrl}$path';
  }
}

class _TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 60,
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
