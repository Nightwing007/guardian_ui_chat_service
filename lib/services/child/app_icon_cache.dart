import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppIconCache {
  static final AppIconCache _instance = AppIconCache._internal();
  factory AppIconCache() => _instance;
  AppIconCache._internal();

  static const _channel = MethodChannel('guardian/monitoring');

  final Map<String, String> _appNames = {};
  final Map<String, ImageProvider> _appIcons = {};
  final Map<String, String> _fallbackInitials = {};

  Future<void> preloadApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getAllInstalledApps');
      if (result == null) return;

      for (final item in result) {
        if (item is Map) {
          final packageName = item['packageName'] as String? ?? '';
          final appName = item['appName'] as String? ?? '';
          final iconBytes = item['iconBytes'] as Uint8List?;

          if (packageName.isEmpty) continue;

          _appNames[packageName] = appName;

          if (iconBytes != null && iconBytes.isNotEmpty) {
            _appIcons[packageName] = MemoryImage(iconBytes);
          } else {
            _fallbackInitials[packageName] =
                appName.isNotEmpty ? appName[0].toUpperCase() : '?';
          }
        }
      }
    } catch (e) {
      debugPrint('Error preloading apps: $e');
    }
  }

  String getAppName(String packageName, {String? fallbackName}) {
    if (_appNames.containsKey(packageName)) {
      return _appNames[packageName]!;
    }

    if (fallbackName != null && fallbackName.isNotEmpty) {
      return fallbackName;
    }

    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      return parts.last;
    }

    return packageName;
  }

  Widget getAppIconWidget(String packageName, {double size = 44}) {
    if (_appIcons.containsKey(packageName)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: _appIcons[packageName]!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final initial = _fallbackInitials[packageName] ?? '?';
    final colorIndex = packageName.hashCode.abs() % _appColors.length;
    final appColor = _appColors[colorIndex];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: appColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static const _appColors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFFB8C00),
    Color(0xFF00ACC1),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF5E35B1),
    Color(0xFF039BE5),
    Color(0xFF7CB342),
    Color(0xFFFF6F00),
  ];
}
