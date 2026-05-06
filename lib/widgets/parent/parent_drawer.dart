import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

class ParentDrawer extends StatelessWidget {
  const ParentDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.parentDrawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Close Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Menu Items
            _buildMenuItem(
              icon: Icons.assignment_outlined,
              label: 'Assign Task',
              isHighlighted: true,
            ),
            const SizedBox(height: 8),
            _buildMenuItem(icon: Icons.block, label: 'Block Sites and apps'),
            const SizedBox(height: 8),
            _buildMenuItem(icon: Icons.trending_up, label: 'Growth Trends'),
            const SizedBox(height: 8),
            _buildMenuItem(icon: Icons.headset_mic_outlined, label: 'Support'),
            const SizedBox(height: 8),
            _buildMenuItem(icon: Icons.settings_outlined, label: 'Settings'),
            const SizedBox(height: 8),
            _buildMenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              badgeCount: 8,
            ),
            const SizedBox(height: 8),
            _buildMenuItem(icon: Icons.info_outline, label: 'Information'),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    bool isHighlighted = false,
    int? badgeCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isHighlighted ? AppColors.parentDrawerIconBg : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (badgeCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.parentDrawerIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
