import 'package:flutter/services.dart';

/// Singleton service for accessibility, VPN and location monitoring.
///
/// Communicates with native Android via [MethodChannel] `guardian/monitoring`.
class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  static const _channel = MethodChannel('guardian/monitoring');

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

  // ── VPN ──────────────────────────────────────────────────────────────

  /// Returns `true` if the local VPN monitor is currently running.
  Future<bool> isVpnRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isVpnRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Starts the local VPN service.
  ///
  /// Returns `'started'` on success or `'needs_permission'` if the user
  /// has not yet approved the VPN connection dialog.
  Future<String> startVpn({List<String>? packages}) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'startVpn',
        packages != null ? {'packages': packages} : null,
      );
      return result ?? 'needs_permission';
    } on PlatformException {
      return 'needs_permission';
    }
  }

  /// Stops the local VPN service.
  Future<void> stopVpn() async {
    try {
      await _channel.invokeMethod<void>('stopVpn');
    } on PlatformException {
      // ignored
    }
  }

  // ── Location ─────────────────────────────────────────────────────────

  /// Returns `true` if the location tracking foreground service is running.
  Future<bool> isLocationTrackingRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLocationTrackingRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Starts location tracking.
  ///
  /// Returns `'started'` on success or `'missing_permission'` when the
  /// required runtime location permissions have not been granted.
  Future<String> startLocationTracking() async {
    try {
      final result = await _channel.invokeMethod<String>('startLocationTracking');
      return result ?? 'missing_permission';
    } on PlatformException {
      return 'missing_permission';
    }
  }

  /// Stops location tracking.
  Future<void> stopLocationTracking() async {
    try {
      await _channel.invokeMethod<void>('stopLocationTracking');
    } on PlatformException {
      // ignored
    }
  }
}
