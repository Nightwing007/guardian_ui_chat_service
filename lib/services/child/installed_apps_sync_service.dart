import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/session_service.dart';

class InstalledAppsSyncService {
  static final InstalledAppsSyncService _instance =
      InstalledAppsSyncService._internal();
  factory InstalledAppsSyncService() => _instance;
  InstalledAppsSyncService._internal();

  static const _channel = MethodChannel('guardian/monitoring');

  Future<void> syncInstalledApps() async {
    final session = await SessionService.getChildSession();
    final deviceToken = session['deviceToken'];
    final childHash = session['childHash'];

    try {
      final apps = await _getInstalledAppsFromNative();

      if (apps.isEmpty) {
        debugPrint('No installed apps to sync');
        return;
      }

      final canSyncToCloud =
          session['role'] == SessionService.childRole &&
          session['isLinked'] == 'true' &&
          deviceToken != null &&
          deviceToken.isNotEmpty &&
          childHash != null &&
          childHash.isNotEmpty;

      if (childHash != null && childHash.isNotEmpty) {
        await AppDatabase().child.upsertInstalledApps(
          apps,
          childHash: childHash,
        );
      }

      if (!canSyncToCloud) {
        debugPrint(
          'Installed apps saved locally; paired cloud credentials are not complete',
        );
        return;
      }

      final cloudApps = apps
          .map(
            (app) => {
              'package_name': app['package_name'],
              'name': app['name'],
              'category': app['category'],
            },
          )
          .toList();

      final result = await AuthService().syncInstalledApps(
        childHash: childHash,
        deviceToken: deviceToken,
        apps: cloudApps,
      );

      if (result['success']) {
        debugPrint('Successfully synced ${apps.length} installed apps');
      } else {
        debugPrint('Failed to sync installed apps: ${result['message']}');
      }
    } catch (e) {
      debugPrint('Error syncing installed apps: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getInstalledAppsFromNative() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getAllInstalledApps',
      );

      if (result == null) return [];

      return result.map((app) {
        final map = app as Map<dynamic, dynamic>;
        final appName = map['appName'] ?? '';
        return {
          'package_name': map['packageName'] ?? '',
          'name': appName,
          'app_name': appName,
          'category': map['category'] ?? 'not available',
          'created': map['created'] ?? 'not available',
          'icon_bytes': map['iconBytes'] != null
              ? base64Encode(List<int>.from(map['iconBytes']))
              : null,
        };
      }).toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed apps from native: ${e.message}');
      return [];
    }
  }
}
