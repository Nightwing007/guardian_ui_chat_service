import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSvgNavItem(0, 'assets/icons/msg.svg'),
            _buildSvgNavItem(1, 'assets/icons/alert.svg'),
            _buildCenterSvgItem(2, 'assets/icons/dashboard.svg'),
            _buildSvgNavItem(3, 'assets/icons/cmd.svg'),
            _buildProfileItem(4),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgNavItem(int index, String assetPath) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(
          assetPath,
          colorFilter: ColorFilter.mode(
            isSelected ? Colors.white : AppColors.iconGrey,
            BlendMode.srcIn,
          ),
          width: 24,
          height: 24,
        ),
      ),
    );
  }

  Widget _buildCenterSvgItem(int index, String assetPath) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1C3270), // Darker blue top
                    Color(0xFF268AE4), // Brighter blue/cyan bottom
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF268AE4).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSelected ? 2.5 : 0.0), // slightly smaller border
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navbarBackground, // Inner circle matches navbar
            ),
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                colorFilter: ColorFilter.mode(
                  isSelected ? Colors.white : AppColors.iconGrey,
                  BlendMode.srcIn,
                ),
                width: 26,
                height: 26,
              ),
            ),
          ),
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
          radius: 13,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.grey, size: 18),
        ),
      ),
    );
  }
}
