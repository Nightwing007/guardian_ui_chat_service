import 'package:flutter/material.dart';

class AppColors {
  // Main background
  static const Color scaffoldBackground = Color(0xFF13151A);

  // Surface colors
  static const Color navbarBackground = Color(0xFF050707);
  static const Color cardBlueBackground = Color(0xFF162032);
  static const Color surfaceOverlay = Color(0xFF1E1E24);

  // Primary Gradient - Used for Navbar selected items and the Apps List background
  static const Color primaryGradientStart = Color(0xFF3B2C3A);
  static const Color primaryGradientEnd = Color(0xFF122034);

  // Welcome Screen & Login
  static const Color primaryPurple = Color(0xFF331682);
  static const Color primaryPurpleDark = Color(0xFF261066);

  // Secondary Gradient - Used for the Motivational/Quote section
  static const Color secondaryGradientStart = Color(0xFF1D3D8B);
  static const Color secondaryGradientEnd = Color(0xFF573B7F);

  // Tertiary Gradient - Used for the Screen Time dashboard card
  static const Color tertiaryGradientStart = Color(0xFF0E2B4B);
  static const Color tertiaryGradientEnd = Color(0xFF071F3A);

  // Action colors
  static const Color sosRed = Color(0xFFD32F2F);
  static const Color accentBlue = Color(0xFF3C64F4);

  // Text / Icon Grey colors
  static Color textGrey = Colors.grey.shade400;
  static Color iconGrey = Colors.grey.shade600;

  // Task Gradients
  static const List<Color> taskGradient1 = [Color(0xFF1A2436), Color(0xFF3B2D3A)];
  static const List<Color> taskGradient2 = [Color(0xFF0E153A), Color(0xFF082265)];
  static const List<Color> taskGradient3 = [Color(0xFF352056), Color(0xFF3A1E60)];
  static const List<Color> taskGradient4 = [Color(0xFF203D8B), Color(0xFF583B7E)];
  static const List<Color> taskGradient5 = [Color(0xFF471637), Color(0xFF5B063F)];

  static const List<List<Color>> allTaskGradients = [
    taskGradient1,
    taskGradient2,
    taskGradient3,
    taskGradient4,
    taskGradient5,
  ];
}
