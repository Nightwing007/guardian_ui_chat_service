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
    await AppDatabase().initialize();

    final session = await SessionService.getChildSession();
    final linkedSettings = await AppDatabase().child.getLinkedChildSettings();
    final deviceToken = _firstNonEmpty([
      linkedSettings['deviceToken'],
      session['deviceToken'],
    ]);
    final childHash = _firstNonEmpty([
      linkedSettings['childHash'],
      session['childHash'],
    ]);

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
              'child_hash': childHash,
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

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
