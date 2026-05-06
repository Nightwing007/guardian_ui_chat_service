import 'dart:async';
import 'package:flutter/services.dart';
import 'package:myapp/services/app_database.dart';

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._internal();
  factory AppBlockerService() => _instance;
  AppBlockerService._internal();

  static const _channel = MethodChannel('guardian/monitoring');
  Timer? _checkTimer;
  final _db = AppDatabase();
  final Set<String> _activeBlockedApps = {};

  Future<void> _syncBlockedApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getBlockedApps');
      if (result != null) {
        _activeBlockedApps.clear();
        _activeBlockedApps.addAll(result.cast<String>());
      }
      await _channel.invokeMethod('syncBlockedApps');
    } on PlatformException catch (e) {
      print('Failed to sync blocked apps: ${e.message}');
    }
  }

  Future<void> startMonitoring() async {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAndBlockApps());
    await _syncBlockedApps();
    await _checkAndBlockApps();
  }

  Future<void> stopMonitoring() async {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _checkAndBlockApps() async {
    await _db.child.refreshUsageData();
    final limits = await _db.child.getAllAppLimits();
    final usageList = await _db.child.appUsageList;

    for (final app in usageList) {
      final limitMinutes = limits[app.packageName];
      if (limitMinutes != null) {
        final usedMinutes = app.totalTimeInForeground.inMinutes;
        if (usedMinutes >= limitMinutes) {
          await _blockApp(app.packageName, app.appName);
        } else {
          await _unblockApp(app.packageName);
        }
      }
    }
  }

  Future<void> _blockApp(String packageName, String appName) async {
    if (_activeBlockedApps.contains(packageName)) return;
    
    try {
      await _channel.invokeMethod('blockApp', {'packageName': packageName});
      _activeBlockedApps.add(packageName);
      print('Blocked app: $packageName ($appName)');
    } on PlatformException catch (e) {
      print('Failed to block app: ${e.message}');
    }
  }

  Future<void> _unblockApp(String packageName) async {
    if (!_activeBlockedApps.contains(packageName)) return;
    
    try {
      await _channel.invokeMethod('unblockApp', {'packageName': packageName});
      _activeBlockedApps.remove(packageName);
    } on PlatformException catch (e) {
      print('Failed to unblock app: ${e.message}');
    }
  }

  Future<bool> isAppBlocked(String packageName) async {
    try {
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