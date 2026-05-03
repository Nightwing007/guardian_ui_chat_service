import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navbarBackground,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = 65.0;
          final int itemCount = 5;
          // Space between items is total internal width minus all item widths, divided by gaps
          final double spacing = (constraints.maxWidth - (itemWidth * itemCount)) / (itemCount - 1);
          final double leftPosition = currentIndex * itemWidth + (currentIndex * spacing);

          return SizedBox(
            height: 65,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: leftPosition,
                  top: 0,
                  width: itemWidth,
                  height: 65,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGradientStart,
                          AppColors.primaryGradientEnd,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(0, Icons.home_filled, 'HOME'),
                    _buildNavItem(1, Icons.bar_chart, 'TASK'),
                    _buildNavItem(2, Icons.chat_bubble_outline, 'CHAT'),
                    _buildNavItem(3, Icons.shield_outlined, 'SAFETY'),
                    _buildNavItem(4, Icons.person_outline, 'PROFILE'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 65,
        height: 65,
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.iconGrey,
              size: 24,
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.iconGrey,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
