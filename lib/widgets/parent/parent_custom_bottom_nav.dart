import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';

class ParentCustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ParentCustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: AppColors.navbarBackground,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.chat_bubble_outline),
          _buildNavItem(1, Icons.campaign_outlined),
          _buildCenterItem(2, Icons.grid_view),
          _buildNavItem(3, Icons.scatter_plot_outlined),
          _buildProfileItem(4),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.iconGrey,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildCenterItem(int index, IconData icon) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF3C64F4) : Colors.transparent, // glowing blue ring
            width: 2,
          ),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.iconGrey,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProfileItem(int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: const CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.grey, size: 20),
        ),
      ),
    );
  }
}
