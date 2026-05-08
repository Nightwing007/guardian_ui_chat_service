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
  bool _isWatchingPackageChanges = false;
  Future<void> _packageChangeQueue = Future.value();

  Future<bool> syncInstalledApps() async {
    await AppDatabase().initialize();

    try {
      final credentials = await _loadSyncCredentials();
      debugPrint('syncInstalledApps - childHash: ${credentials.childHash}, canSyncToCloud: ${credentials.canSyncToCloud}');

      final apps = await _getInstalledAppsFromNative();
      debugPrint('syncInstalledApps - native apps count: ${apps.length}');

      if (apps.isEmpty) {
        debugPrint('No installed apps to sync');
        return false;
      }

      if (credentials.childHash != null) {
        debugPrint('syncInstalledApps - saving ${apps.length} apps to local DB for childHash: ${credentials.childHash}');
        await AppDatabase().child.upsertInstalledApps(
          apps,
          childHash: credentials.childHash!,
        );
      } else {
        debugPrint('syncInstalledApps - childHash is null, not saving to local DB');
      }

      if (!credentials.canSyncToCloud) {
        debugPrint(
          'Installed apps saved locally; paired cloud credentials are not complete',
        );
        return false;
      }

      return _syncAppsToCloud(
        apps: apps,
        childHash: credentials.childHash!,
        deviceToken: credentials.deviceToken!,
      );
    } catch (e) {
      debugPrint('Error syncing installed apps: $e');
      return false;
    }
  }

  Future<bool> syncLocalInstalledAppsToCloud() async {
    await AppDatabase().initialize();

    try {
      final credentials = await _loadSyncCredentials();
      if (!credentials.canSyncToCloud) {
        debugPrint(
          'Local installed apps not synced; cloud credentials missing',
        );
        return false;
      }

      final apps = await AppDatabase().child.getInstalledApps(
        childHash: credentials.childHash,
      );

      if (apps.isEmpty) {
        debugPrint('No local installed apps to sync');
        return false;
      }

      return _syncAppsToCloud(
        apps: apps,
        childHash: credentials.childHash!,
        deviceToken: credentials.deviceToken!,
      );
    } catch (e) {
      debugPrint('Error syncing local installed apps: $e');
      return false;
    }
  }

  Future<void> startPackageChangeWatcher() async {
    if (_isWatchingPackageChanges) return;
    _isWatchingPackageChanges = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installedAppsChanged') return null;

      final args = Map<String, dynamic>.from(call.arguments as Map);
      final packageName = args['packageName'] as String?;
      final changeType = args['changeType'] as String?;
      if (packageName == null || packageName.trim().isEmpty) return null;

      _packageChangeQueue = _packageChangeQueue.then(
        (_) => _handlePackageChange(
          packageName: packageName,
          changeType: changeType ?? 'changed',
        ),
      );
      await _packageChangeQueue;

      return null;
    });

    try {
      await _channel.invokeMethod<void>('startInstalledAppsWatcher');
    } on PlatformException catch (e) {
      debugPrint('Failed to start installed apps watcher: ${e.message}');
      _isWatchingPackageChanges = false;
    }
  }

  Future<void> stopPackageChangeWatcher() async {
    if (!_isWatchingPackageChanges) return;
    _isWatchingPackageChanges = false;
    _channel.setMethodCallHandler(null);

    try {
      await _channel.invokeMethod<void>('stopInstalledAppsWatcher');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop installed apps watcher: ${e.message}');
    }
  }

  Future<bool> _syncAppsToCloud({
    required List<Map<String, dynamic>> apps,
    required String childHash,
    required String deviceToken,
  }) async {
    final cloudApps = apps
        .map(
          (app) => {
            'package_name': app['package_name'],
            'name': app['name'] ?? app['app_name'],
            'category': app['category'] ?? 'not available',
            'child_hash': childHash,
          },
        )
        .where((app) => (app['package_name'] as String?)?.isNotEmpty == true)
        .toList();

    if (cloudApps.isEmpty) return false;

    final result = await AuthService().syncInstalledApps(
      childHash: childHash,
      deviceToken: deviceToken,
      apps: cloudApps,
    );

    if (result['success']) {
      debugPrint('Successfully synced ${cloudApps.length} installed apps');
      return true;
    } else {
      debugPrint('Failed to sync installed apps: ${result['message']}');
      return false;
    }
  }

  Future<void> _handlePackageChange({
    required String packageName,
    required String changeType,
  }) async {
    try {
      await AppDatabase().initialize();
      final credentials = await _loadSyncCredentials();
      final childHash = credentials.childHash;

      if (childHash == null || childHash.isEmpty) {
        debugPrint('Package change ignored; child hash missing');
        return;
      }

      if (changeType == 'removed') {
        await AppDatabase().child.deleteInstalledApp(
          packageName: packageName,
          childHash: childHash,
        );
      } else {
        final app = await _getInstalledAppFromNative(packageName);
        if (app != null) {
          await AppDatabase().child.upsertInstalledApps([
            app,
          ], childHash: childHash);
        }
      }

      await syncLocalInstalledAppsToCloud();
    } catch (e) {
      debugPrint('Error handling package change: $e');
    }
  }

  Future<_SyncCredentials> _loadSyncCredentials() async {
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

    return _SyncCredentials(deviceToken: deviceToken, childHash: childHash);
  }

  Future<Map<String, dynamic>?> _getInstalledAppFromNative(
    String packageName,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInstalledApp',
        {'packageName': packageName},
      );

      if (result == null) return null;

      return _mapNativeApp(result);
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed app from native: ${e.message}');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getInstalledAppsFromNative() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getAllInstalledApps',
      );

      if (result == null) return [];

      return result
          .map((app) => _mapNativeApp(app as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed apps from native: ${e.message}');
      return [];
    }
  }

  Map<String, dynamic> _mapNativeApp(Map<dynamic, dynamic> map) {
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

class _SyncCredentials {
  final String? deviceToken;
  final String? childHash;

  const _SyncCredentials({required this.deviceToken, required this.childHash});

  bool get canSyncToCloud => deviceToken != null && childHash != null;
}
