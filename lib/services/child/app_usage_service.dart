import 'package:flutter/services.dart';

/// Per-app usage statistics for a single period.
class AppUsageInfo {
  final String packageName;
  final String appName;
  final Duration totalTimeInForeground;
  final DateTime lastTimeUsed;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.totalTimeInForeground,
    required this.lastTimeUsed,
  });

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? map['packageName'] as String? ?? '',
      totalTimeInForeground: Duration(
        milliseconds: (map['totalTimeInForeground'] as num?)?.toInt() ?? 0,
      ),
      lastTimeUsed: DateTime.fromMillisecondsSinceEpoch(
        (map['lastTimeUsed'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Singleton service for usage stats and overlay permission management.
///
/// Communicates with native Android via [MethodChannel] `guardian/monitoring`.
class AppUsageService {
  static final AppUsageService _instance = AppUsageService._internal();
  factory AppUsageService() => _instance;
  AppUsageService._internal();

  static const _channel = MethodChannel('guardian/monitoring');

  // ── Usage Stats ──────────────────────────────────────────────────────

  /// Returns `true` if the app has usage-stats access.
  Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's "Usage Access" settings page so the user can grant
  /// the permission manually.
  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException {
      // ignored — user can still navigate manually
    }
  }

  /// Fetches today's per-app usage stats from the native UsageStatsManager.
  ///
  /// Returns a list of [AppUsageInfo] sorted by foreground time descending.
  /// Requires usage-stats permission to be granted first.
  Future<List<AppUsageInfo>> getTodayUsage() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getTodayUsageStats');
      if (result == null) return [];

      final List<AppUsageInfo> usageList = [];
      for (final item in result) {
        if (item is Map) {
          try {
            usageList.add(AppUsageInfo.fromMap(item));
          } catch (_) {
            // Skip malformed entries
          }
        }
      }
      return usageList;
    } on PlatformException {
      return [];
    }
  }

  // ── Overlay ──────────────────────────────────────────────────────────

  /// Returns `true` if the app can draw overlays (draw over other apps).
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's "Display over other apps" settings page.
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod<void>('requestOverlayPermission');
    } on PlatformException {
      // ignored
    }
  }

  // ── Accessibility ────────────────────────────────────────────────────

  /// Returns `true` if the Guardian AI accessibility service is enabled.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's Accessibility settings page.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException {
      // ignored
    }
  }
}
