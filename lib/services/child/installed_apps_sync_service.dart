import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/session_service.dart';

class InstalledAppsSyncService {
  static final InstalledAppsSyncService _instance = InstalledAppsSyncService._internal();
  factory InstalledAppsSyncService() => _instance;
  InstalledAppsSyncService._internal();

  static const _channel = MethodChannel('guardian/monitoring');

  Future<void> syncInstalledApps() async {
    final session = await SessionService.getChildSession();
    final deviceToken = session['deviceToken'];

    if (deviceToken == null) {
      print('No device token found, skipping installed apps sync');
      return;
    }

    try {
      final apps = await _getInstalledAppsFromNative();
      
      if (apps.isEmpty) {
        print('No installed apps to sync');
        return;
      }

      final result = await AuthService().syncInstalledApps(
        deviceToken: deviceToken,
        apps: apps,
      );

      if (result['success']) {
        print('Successfully synced ${apps.length} installed apps');
      } else {
        print('Failed to sync installed apps: ${result['message']}');
      }
    } catch (e) {
      print('Error syncing installed apps: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getInstalledAppsFromNative() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getAllInstalledApps');
      
      if (result == null) return [];

      return result.map((app) {
        final map = app as Map<dynamic, dynamic>;
        return {
          'package_name': map['packageName'] ?? '',
          'app_name': map['appName'] ?? '',
          'icon_bytes': map['iconBytes'] != null 
              ? base64Encode(List<int>.from(map['iconBytes']))
              : null,
        };
      }).toList();
    } on PlatformException catch (e) {
      print('Failed to get installed apps from native: ${e.message}');
      return [];
    }
  }
}