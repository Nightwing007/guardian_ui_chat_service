import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppParentDatabase {
  static final AppParentDatabase _instance = AppParentDatabase._internal();
  factory AppParentDatabase() => _instance;
  AppParentDatabase._internal();

  Database? _db;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final dbPath = p.join(await getDatabasesPath(), 'guardian_ai_parent.db');
    _db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE child (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        child_hash TEXT NOT NULL UNIQUE,
        first_name TEXT,
        last_name TEXT,
        date_of_birth TEXT,
        is_paired INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    await _createAppUsageTable(db);
    await _createInstalledAppsTable(db);
    await _createAppLimitsTable(db);
    await _createTasksTable(db);
    await _createSelectedChildTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAppUsageTable(db);
    }
    if (oldVersion < 3) {
      await _createInstalledAppsTable(db);
    }
    if (oldVersion < 4) {
      await _createAppLimitsTable(db);
    }
    if (oldVersion < 5) {
      await _createTasksTable(db);
    }
    if (oldVersion < 6) {
      await _createSelectedChildTable(db);
    }
  }

  Future<void> _createAppUsageTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_hash TEXT NOT NULL,
        usage_date TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        foreground_ms INTEGER NOT NULL DEFAULT 0,
        opens INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        UNIQUE(child_hash, usage_date, package_name)
      )
    ''');
  }

  Future<void> _createInstalledAppsTable(Database db) async {
    await db.execute('''
      CREATE TABLE installed_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        child_hash TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        category TEXT,
        icon_bytes TEXT,
        raw_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        UNIQUE(child_hash, package_name)
      )
    ''');
  }

  Future<void> _createAppLimitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_limits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_hash TEXT NOT NULL,
        package_name TEXT NOT NULL,
        remote_id INTEGER,
        cloud_limit_id INTEGER,
        limit_minutes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        UNIQUE(child_hash, package_name)
      )
    ''');
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        duration INTEGER NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        reward_points INTEGER NOT NULL DEFAULT 3,
        completed_at TEXT,
        created TEXT NOT NULL,
        updated TEXT NOT NULL,
        child_hash TEXT NOT NULL,
        guardian_id INTEGER,
        UNIQUE(child_hash, name, created)
      )
    ''');
  }

  Future<void> _createSelectedChildTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS selected_child (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        child_hash TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        date_of_birth TEXT,
        is_paired INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        selected_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> upsertChildren(List<Map<String, dynamic>> children) async {
    await initialize();
    final db = _requireDb();
    final batch = db.batch();
    final syncedAt = DateTime.now().toIso8601String();

    for (final child in children) {
      final childHash = child['child_hash']?.toString().trim() ?? '';
      if (childHash.isEmpty) continue;

      batch.insert('child', {
        'remote_id': _firstNonEmpty([
          child['id']?.toString(),
          child['child_id']?.toString(),
        ]),
        'child_hash': childHash,
        'first_name': child['first_name']?.toString(),
        'last_name': child['last_name']?.toString(),
        'date_of_birth': child['date_of_birth']?.toString(),
        'is_paired': child['is_paired'] == true ? 1 : 0,
        'raw_json': jsonEncode(child),
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    await initialize();
    final rows = await _requireDb().query('child', orderBy: 'first_name ASC');

    return rows.map((row) {
      final rawJson = row['raw_json'] as String?;
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          // Fall back to the normalized columns below.
        }
      }

      return {
        'id': row['remote_id'],
        'child_hash': row['child_hash'],
        'first_name': row['first_name'],
        'last_name': row['last_name'],
        'date_of_birth': row['date_of_birth'],
        'is_paired': row['is_paired'] == 1,
      };
    }).toList();
  }

  Future<void> selectChild(Map<String, dynamic> child) async {
    await initialize();
    final childHash = child['child_hash']?.toString().trim() ?? '';
    if (childHash.isEmpty) return;

    final selectedAt = DateTime.now().toIso8601String();
    await _requireDb().insert('selected_child', {
      'id': 1,
      'child_hash': childHash,
      'first_name': child['first_name']?.toString(),
      'last_name': child['last_name']?.toString(),
      'date_of_birth': child['date_of_birth']?.toString(),
      'is_paired': child['is_paired'] == true ? 1 : 0,
      'raw_json': jsonEncode(child),
      'selected_at': selectedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getSelectedChild() async {
    await initialize();
    final rows = await _requireDb().query(
      'selected_child',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final rawJson = row['raw_json'] as String?;
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Fall back to normalized columns below.
      }
    }

    return {
      'child_hash': row['child_hash'],
      'first_name': row['first_name'],
      'last_name': row['last_name'],
      'date_of_birth': row['date_of_birth'],
      'is_paired': row['is_paired'] == 1,
    };
  }

  Future<Map<String, dynamic>?> ensureSelectedChild({
    String? preferredChildHash,
  }) async {
    await initialize();
    final children = await getChildren();
    if (children.isEmpty) {
      await _requireDb().delete('selected_child');
      return null;
    }

    final selected = await getSelectedChild();
    final selectedHash = selected?['child_hash']?.toString();
    final stillExists = children.any(
      (child) => child['child_hash']?.toString() == selectedHash,
    );
    if (stillExists) return selected;

    final preferredHash = preferredChildHash?.trim();
    Map<String, dynamic>? preferred;
    if (preferredHash != null && preferredHash.isNotEmpty) {
      for (final child in children) {
        if (child['child_hash']?.toString() == preferredHash) {
          preferred = child;
          break;
        }
      }
    }

    final fallback = preferred ?? children.first;
    await selectChild(fallback);
    return fallback;
  }

  Future<void> upsertChildUsage({
    required String childHash,
    required Map<String, dynamic> usageData,
    String? date,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final usageDate = date ?? _todayKey();
    final apps = usageData['apps'];
    if (apps is! List) return;

    final db = _requireDb();
    final batch = db.batch();
    final fetchedAt = DateTime.now().toIso8601String();

    batch.delete(
      'app_usage',
      where: 'child_hash = ? AND usage_date = ?',
      whereArgs: [trimmedChildHash, usageDate],
    );

    for (final app in apps.whereType<Map>()) {
      final packageName = app['package_name']?.toString().trim() ?? '';
      if (packageName.isEmpty) continue;

      batch.insert('app_usage', {
        'child_hash': trimmedChildHash,
        'usage_date': usageDate,
        'package_name': packageName,
        'app_name': app['app_name']?.toString() ?? packageName,
        'foreground_ms': _asInt(app['foreground_ms']),
        'opens': _asInt(app['opens']),
        'raw_json': jsonEncode(app),
        'fetched_at': fetchedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>> getChildUsage({
    required String childHash,
    String? date,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) {
      return {'apps': <Map<String, dynamic>>[], 'total_foreground_ms': 0};
    }

    final rows = await _requireDb().query(
      'app_usage',
      where: 'child_hash = ? AND usage_date = ?',
      whereArgs: [trimmedChildHash, date ?? _todayKey()],
      orderBy: 'foreground_ms DESC',
    );

    final apps = rows.map((row) {
      final rawJson = row['raw_json'] as String?;
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          // Fall back to normalized columns below.
        }
      }

      return {
        'package_name': row['package_name'],
        'app_name': row['app_name'],
        'foreground_ms': row['foreground_ms'],
        'opens': row['opens'],
      };
    }).toList();

    final totalMs = apps.fold<int>(
      0,
      (sum, app) => sum + _asInt(app['foreground_ms']),
    );

    return {'apps': apps, 'total_foreground_ms': totalMs};
  }

  Future<List<Map<String, dynamic>>> getUsageApps({
    required String childHash,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return [];

    final rows = await _requireDb().query(
      'app_usage',
      columns: ['package_name', 'app_name'],
      where: 'child_hash = ?',
      whereArgs: [trimmedChildHash],
      orderBy: 'app_name ASC',
    );

    return rows
        .map(
          (row) => {
            'package_name': row['package_name']?.toString() ?? '',
            'app_name': row['app_name']?.toString() ?? '',
          },
        )
        .where((app) => (app['package_name'] as String).isNotEmpty)
        .toList();
  }

  Future<void> upsertInstalledApps({
    required String childHash,
    required List<Map<String, dynamic>> apps,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final db = _requireDb();
    final batch = db.batch();
    final fetchedAt = DateTime.now().toIso8601String();

    batch.delete(
      'installed_apps',
      where: 'child_hash = ?',
      whereArgs: [trimmedChildHash],
    );

    for (final app in apps) {
      final packageName = app['package_name']?.toString().trim() ?? '';
      if (packageName.isEmpty) continue;

      batch.insert('installed_apps', {
        'remote_id': _asNullableInt(app['id']),
        'child_hash': trimmedChildHash,
        'package_name': packageName,
        'app_name':
            _firstNonEmpty([
              app['app_name']?.toString(),
              app['name']?.toString(),
            ]) ??
            packageName,
        'category': app['category']?.toString(),
        'icon_bytes': app['icon_bytes']?.toString(),
        'raw_json': jsonEncode(app),
        'fetched_at': fetchedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getInstalledApps({
    required String childHash,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return [];

    final rows = await _requireDb().query(
      'installed_apps',
      where: 'child_hash = ?',
      whereArgs: [trimmedChildHash],
      orderBy: 'app_name ASC',
    );

    return rows.map((row) {
      final rawJson = row['raw_json'] as String?;
      final localId = _asInt(row['id']);
      final remoteId = _asNullableInt(row['remote_id']);

      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            final app = Map<String, dynamic>.from(decoded);
            app['id'] = remoteId ?? localId;
            app['app_name'] =
                _firstNonEmpty([
                  app['app_name']?.toString(),
                  app['name']?.toString(),
                ]) ??
                row['app_name'];
            return app;
          }
        } catch (_) {
          // Fall back to normalized columns below.
        }
      }

      return {
        'id': remoteId ?? localId,
        'package_name': row['package_name'],
        'app_name': row['app_name'],
        'category': row['category'],
        'icon_bytes': row['icon_bytes'],
      };
    }).toList();
  }

  Future<void> clearChildUsage({String? childHash}) async {
    await initialize();
    if (childHash == null || childHash.trim().isEmpty) {
      await _requireDb().delete('app_usage');
      return;
    }

    await _requireDb().delete(
      'app_usage',
      where: 'child_hash = ?',
      whereArgs: [childHash.trim()],
    );
  }

  Future<void> upsertAppLimit({
    required String childHash,
    required String packageName,
    int? remoteId,
    int? cloudLimitId,
    required int limitMinutes,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final trimmedPackage = packageName.trim();
    if (trimmedPackage.isEmpty) return;

    try {
      await _requireDb().insert('app_limits', {
        'child_hash': trimmedChildHash,
        'package_name': trimmedPackage,
        'remote_id': remoteId,
        'cloud_limit_id': cloudLimitId,
        'limit_minutes': limitMinutes,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print(
        'upsertAppLimit: Inserted for $trimmedPackage with $limitMinutes minutes',
      );
    } catch (e) {
      print('upsertAppLimit error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAppLimits({
    required String childHash,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return [];

    final rows = await _requireDb().query(
      'app_limits',
      where: 'child_hash = ?',
      whereArgs: [trimmedChildHash],
    );

    return rows
        .map(
          (row) => {
            'package_name': row['package_name'],
            'remote_id': row['remote_id'],
            'cloud_limit_id': row['cloud_limit_id'],
            'limit_minutes': row['limit_minutes'],
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>> upsertTask({
    required String childHash,
    required String name,
    required String category,
    required int duration,
    int? remoteId,
    String state = 'pending',
    int rewardPoints = 3,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) {
      return {'success': false, 'message': 'child_hash is required'};
    }

    final now = DateTime.now().toIso8601String();
    try {
      await _requireDb().insert('tasks', {
        'remote_id': remoteId,
        'name': name,
        'category': category,
        'duration': duration,
        'state': state,
        'reward_points': rewardPoints,
        'completed_at': null,
        'created': now,
        'updated': now,
        'child_hash': trimmedChildHash,
        'guardian_id': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return {'success': true};
    } catch (e) {
      print('upsertTask error: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  Future<List<Map<String, dynamic>>> getTasks({
    required String childHash,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return [];

    final rows = await _requireDb().query(
      'tasks',
      where: 'child_hash = ?',
      whereArgs: [trimmedChildHash],
      orderBy: 'created DESC',
    );

    return rows
        .map(
          (row) => {
            'id': row['id'],
            'remote_id': row['remote_id'],
            'name': row['name'],
            'category': row['category'],
            'duration': row['duration'],
            'state': row['state'],
            'reward_points': row['reward_points'],
            'completed_at': row['completed_at'],
            'created': row['created'],
            'updated': row['updated'],
            'child_hash': row['child_hash'],
            'guardian_id': row['guardian_id'],
          },
        )
        .toList();
  }

  Future<void> deleteTask({required int localId}) async {
    await initialize();
    await _requireDb().delete('tasks', where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> updateTaskRemoteId({
    required String childHash,
    required String name,
    required int remoteId,
  }) async {
    await initialize();
    final now = DateTime.now().toIso8601String();
    await _requireDb().update(
      'tasks',
      {'remote_id': remoteId, 'updated': now},
      where: 'child_hash = ? AND name = ?',
      whereArgs: [childHash.trim(), name],
    );
  }

  Future<void> deleteAppLimit({
    required String childHash,
    required String packageName,
  }) async {
    await initialize();
    final trimmedChildHash = childHash.trim();
    final trimmedPackage = packageName.trim();
    if (trimmedChildHash.isEmpty || trimmedPackage.isEmpty) return;

    await _requireDb().delete(
      'app_limits',
      where: 'child_hash = ? AND package_name = ?',
      whereArgs: [trimmedChildHash, trimmedPackage],
    );
  }

  Future<void> clearChildren() async {
    await initialize();
    await _requireDb().delete('installed_apps');
    await _requireDb().delete('app_usage');
    await _requireDb().delete('selected_child');
    await _requireDb().delete('child');
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('Parent database is not initialized');
    }
    return db;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String _todayKey() => DateTime.now().toIso8601String().split('T').first;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
