import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:myapp/services/app_database.dart';

/// Keeps native enforcement in sync with SQLite:
/// 1. [app_limits] → native ms limits (for overlay service / usage stats path).
/// 2. [enforced_app_blocks] → derived by comparing limits to live usage; the
///    package list is pushed to accessibility so over-limit apps are closed.
class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  static const _channel = MethodChannel('guardian/monitoring');
  final _db = AppDatabase();
  Timer? _enforceTimer;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pushes [app_limits] rows to native SharedPreferences and ensures the
  /// foreground blocker service is running.
  Future<void> syncNativeLimitsFromDatabase() async {
    if (!_isAndroid) return;
    try {
      final dbLimits = await _db.child.getAllAppLimits();
      final nativeRaw = await _channel.invokeMethod<dynamic>('getAppLimits');
      final nativeKeys = <String>{};
      if (nativeRaw is Map) {
        for (final k in nativeRaw.keys) {
          nativeKeys.add(k.toString());
        }
      }
      for (final pkg in nativeKeys) {
        if (!dbLimits.containsKey(pkg)) {
          await _channel.invokeMethod('removeAppLimit', {'packageName': pkg});
        }
      }
      for (final e in dbLimits.entries) {
        await _channel.invokeMethod('setAppLimit', {
          'packageName': e.key,
          'limitMs': e.value * 60 * 1000,
        });
      }
      await _channel.invokeMethod('startBlocker');
    } on PlatformException catch (e) {
      debugPrint('Failed to sync native app limits: ${e.message}');
    }
  }

  /// Rebuilds [enforced_app_blocks] and replaces the native accessibility
  /// blocklist (HOME + BACK when those apps open).
  Future<void> refreshEnforcementFromDatabase() async {
    if (!_isAndroid) return;
    try {
      final blocked = await _db.child.recomputeEnforcedAppBlocks();
      await _channel.invokeMethod('syncEnforcedBlocklist', {
        'packages': blocked.toList(),
      });
      debugPrint(
        'Enforced blocks synced: ${blocked.length} pkgs → native',
      );
    } on PlatformException catch (e) {
      debugPrint('Failed to sync enforced blocklist: ${e.message}');
    }
  }

  Future<void> startMonitoring() async {
    _enforceTimer?.cancel();
    await syncNativeLimitsFromDatabase();
    await refreshEnforcementFromDatabase();
    _enforceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshEnforcementFromDatabase(),
    );
  }

  Future<void> stopMonitoring() async {
    _enforceTimer?.cancel();
    _enforceTimer = null;
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopBlocker');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop app blocker: ${e.message}');
    }
  }

  Future<bool> isAppBlocked(String packageName) async {
    try {
      final enforced = await _db.child.getEnforcedAppBlockPackages();
      if (enforced.contains(packageName)) return true;
      final result = await _channel.invokeMethod<bool>(
        'isAppBlocked',
        {'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
