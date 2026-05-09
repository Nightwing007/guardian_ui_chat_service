import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:myapp/models/child/task_model.dart';
import 'package:myapp/models/child/chat_message.dart';
import 'package:myapp/services/child/app_usage_service.dart';

/// Central SQLite-backed database for the Guardian AI app.
///
/// Two logical partitions — [child] and [parent] — backed by tables in a
/// single SQLite file (`guardian_ai.db`).
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  /// The child partition — settings, tasks, app-limits, and live usage cache.
  final ChildData child = ChildData();

  /// The parent partition — placeholder for future features.
  final ParentData parent = ParentData();

  // ── Initialization ──────────────────────────────────────────────────

  bool _initialized = false;

  /// Opens (or creates) the SQLite database, seeds default data on first
  /// run, and hydrates the live-usage cache from the native platform.
  /// Safe to call multiple times — only runs once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final dbPath = p.join(await getDatabasesPath(), 'guardian_ai.db');
    _db = await openDatabase(
      dbPath,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    child._db = _db!;

    // Hydrate live usage data from native (not stored in SQLite).
    await child.refreshUsageData();
  }

  /// Called once when the database file is first created.
  Future<void> _onCreate(Database db, int version) async {
    // ── child_settings ──
    await db.execute('''
      CREATE TABLE child_settings (
        id INTEGER PRIMARY KEY,
        device_token TEXT,
        child_hash TEXT,
        child_name TEXT,
        total_allowed_screen_time_minutes INTEGER NOT NULL DEFAULT 240,
        total_points INTEGER NOT NULL DEFAULT 10
      )
    ''');
    await db.insert('child_settings', {
      'id': 1,
      'device_token': null,
      'child_hash': null,
      'child_name': null,
      'total_allowed_screen_time_minutes': 600,
      'total_points': 500,
    });

    // ── tasks ──
    await _createTasksTable(db);

    // Seed tasks from the bundled JSON asset.
    try {
      final jsonString = await rootBundle.loadString('assets/data/tasks.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      for (final item in jsonList) {
        await db.insert('tasks', {
          'id': item['id'],
          'name': item['name'],
          'category': item['category'],
          'timer_time': item['timerTime'],
          'state': item['state'] ?? 'initial',
        });
      }
    } catch (_) {
      // If JSON is missing or malformed, we just start with no tasks.
    }

    // ── app_limits ──
    await db.execute('''
      CREATE TABLE app_limits (
        package_name TEXT PRIMARY KEY,
        app_name TEXT NOT NULL,
        allowed_minutes INTEGER NOT NULL
      )
    ''');

    // ── chat_messages ──
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        time TEXT NOT NULL,
        is_me INTEGER NOT NULL,
        is_seen INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Seed some sample chat messages
    final now = DateTime.now();
    final sampleMessages = [
      {
        'text': 'Hey Alex! How was thr your day?',
        'time': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'is_me': 0,
        'is_seen': 1,
      },
      {
        'text': 'It was good! I finished my homework.',
        'time': now
            .subtract(const Duration(hours: 1, minutes: 45))
            .toIso8601String(),
        'is_me': 1,
        'is_seen': 1,
      },
      {
        'text': 'That\'s great! Keep it up!',
        'time': now
            .subtract(const Duration(hours: 1, minutes: 30))
            .toIso8601String(),
        'is_me': 0,
        'is_seen': 1,
      },
      {
        'text': 'Thanks Mom! Can I have more screen time?',
        'time': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'is_me': 1,
        'is_seen': 1,
      },
      {
        'text': 'Complete your tasks first!',
        'time': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'is_me': 0,
        'is_seen': 0,
      },
    ];
    for (final msg in sampleMessages) {
      await db.insert('chat_messages', msg);
    }

    await _createInstalledAppsTable(db);
    await _createLocalAppUsageTable(db);
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY,
        remote_id INTEGER,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        timer_time TEXT NOT NULL DEFAULT '5m',
        duration INTEGER NOT NULL DEFAULT 0,
        state TEXT NOT NULL DEFAULT 'initial',
        reward_points INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created TEXT NOT NULL,
        updated TEXT NOT NULL,
        child_hash TEXT,
        UNIQUE(remote_id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.update('child_settings', {
        'total_allowed_screen_time_minutes': 600,
      }, where: 'id = 1');
    }
    if (oldVersion < 3) {
      // Create chat_messages table
      await db.execute('''
        CREATE TABLE chat_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL,
          time TEXT NOT NULL,
          is_me INTEGER NOT NULL,
          is_seen INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Seed sample messages
      final now = DateTime.now();
      final sampleMessages = [
        {
          'text': 'Hey Alex! How was your day?',
          'time': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'is_me': 0,
          'is_seen': 1,
        },
        {
          'text': 'It was good! I finished my homework.',
          'time': now
              .subtract(const Duration(hours: 1, minutes: 45))
              .toIso8601String(),
          'is_me': 1,
          'is_seen': 1,
        },
        {
          'text': 'That\'s great! Keep it up!',
          'time': now
              .subtract(const Duration(hours: 1, minutes: 30))
              .toIso8601String(),
          'is_me': 0,
          'is_seen': 1,
        },
        {
          'text': 'Thanks Mom! Can I have more screen time?',
          'time': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'is_me': 1,
          'is_seen': 1,
        },
        {
          'text': 'Complete your tasks first!',
          'time': now.subtract(const Duration(minutes: 30)).toIso8601String(),
          'is_me': 0,
          'is_seen': 0,
        },
      ];
      for (final msg in sampleMessages) {
        await db.insert('chat_messages', msg);
      }
    }
    if (oldVersion < 4) {
      await _createInstalledAppsTable(db);
    }
    if (oldVersion < 5) {
      await _createLocalAppUsageTable(db);
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(db, 'child_settings', 'device_token', 'TEXT');
      await _addColumnIfMissing(db, 'child_settings', 'child_hash', 'TEXT');
      await _addColumnIfMissing(db, 'child_settings', 'child_name', 'TEXT');
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(db, 'installed_apps', 'child_hash', 'TEXT');
      await _addColumnIfMissing(db, 'local_app_usage', 'child_hash', 'TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS installed_apps_package_child_hash_idx '
        'ON installed_apps(package_name, child_hash)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS local_app_usage_package_child_hash_idx '
        'ON local_app_usage(package_name, child_hash)',
      );
    }
    if (oldVersion < 8) {
      // Just ensure the tasks table has new columns
      await _addColumnIfMissing(db, 'tasks', 'remote_id', 'INTEGER');
      await _addColumnIfMissing(db, 'tasks', 'duration', 'INTEGER DEFAULT 0');
      await _addColumnIfMissing(
        db,
        'tasks',
        'reward_points',
        'INTEGER DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'tasks', 'completed_at', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'created', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'updated', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'child_hash', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createInstalledAppsTable(Database db) async {
    await db.execute('''
      CREATE TABLE installed_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        created TEXT NOT NULL,
        child_hash TEXT NOT NULL,
        UNIQUE(package_name, child_hash)
      )
    ''');
  }

  Future<void> _createLocalAppUsageTable(Database db) async {
    await db.execute('''
      CREATE TABLE local_app_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        foreground_ms INTEGER NOT NULL,
        opens INTEGER NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL,
        child_hash TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(package_name, child_hash)
      )
    ''');
  }
}

class ChildData {
  final _appUsageService = AppUsageService();

  /// Set by [AppDatabase.initialize] after the DB is opened.
  late Database _db;

  // ── Live usage cache (not persisted in SQLite) ────────────────────

  /// Today's per-app usage stats from the native platform.
  List<AppUsageInfo> appUsageList = [];

  /// Total screen time used today.
  Duration totalUsedScreenTime = Duration.zero;

  bool _usageLoading = true;
  bool get isUsageLoading => _usageLoading;

  /// Fetches today's usage stats from the native platform and caches them.
  Future<void> refreshUsageData() async {
    _usageLoading = true;

    final hasPermission = await _appUsageService.hasUsageStatsPermission();
    if (!hasPermission) {
      appUsageList = [];
      totalUsedScreenTime = Duration.zero;
      _usageLoading = false;
      return;
    }

    final usage = await _appUsageService.getTodayUsage();
    final totalMs = usage.fold<int>(
      0,
      (sum, app) => sum + app.totalTimeInForeground.inMilliseconds,
    );

    appUsageList = usage;
    totalUsedScreenTime = Duration(milliseconds: totalMs);
    _usageLoading = false;
  }

  // ── Screen Time (SQLite) ──────────────────────────────────────��─��─

  /// Total allowed screen time in minutes (from DB).
  Future<int> getTotalAllowedScreenTimeMinutes() async {
    final rows = await _db.query('child_settings', where: 'id = 1');
    if (rows.isEmpty) return 240;
    return rows.first['total_allowed_screen_time_minutes'] as int;
  }

  Future<void> setTotalAllowedScreenTimeMinutes(int minutes) async {
    await _db.update('child_settings', {
      'total_allowed_screen_time_minutes': minutes,
    }, where: 'id = 1');
  }

  Future<void> saveLinkedChildSettings({
    required String deviceToken,
    required String childHash,
    required String childName,
  }) async {
    final values = {
      'device_token': deviceToken,
      'child_hash': childHash,
      'child_name': childName,
    };

    final count = await _db.update('child_settings', values, where: 'id = 1');

    if (count == 0) {
      await _db.insert('child_settings', {'id': 1, ...values});
    }
  }

  Future<Map<String, String?>> getLinkedChildSettings() async {
    final rows = await _db.query('child_settings', where: 'id = 1');
    if (rows.isEmpty) {
      return {'deviceToken': null, 'childHash': null, 'childName': null};
    }

    final row = rows.first;
    return {
      'deviceToken': row['device_token'] as String?,
      'childHash': row['child_hash'] as String?,
      'childName': row['child_name'] as String?,
    };
  }

  /// How much time the child still has left today.
  Future<Duration> getTimeRemaining() async {
    final allowedMin = await getTotalAllowedScreenTimeMinutes();
    final allowed = Duration(minutes: allowedMin);
    final remaining = allowed - totalUsedScreenTime;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // ── Points (SQLite) ───────────────────────────────────────────────

  Future<int> getTotalPoints() async {
    final rows = await _db.query('child_settings', where: 'id = 1');
    if (rows.isEmpty) return 10;
    return rows.first['total_points'] as int;
  }

  Future<void> setTotalPoints(int points) async {
    await _db.update('child_settings', {
      'total_points': points,
    }, where: 'id = 1');
  }

  Future<void> addPoints(int amount) async {
    final current = await getTotalPoints();
    await setTotalPoints(current + amount);
  }

  // ── Tasks (SQLite) ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTasks() async {
    final rows = await _db.query('tasks', orderBy: 'created DESC');
    return rows.map((row) {
      return {
        'id': row['id'],
        'remote_id': row['remote_id'],
        'name': row['name'],
        'category': row['category'],
        'duration': row['duration'] ?? 0,
        'state': row['state'],
        'reward_points': row['reward_points'] ?? 0,
        'completed_at': row['completed_at'],
        'created': row['created'],
        'updated': row['updated'],
      };
    }).toList();
  }

  Future<List<TaskModel>> getTaskModels() async {
    final rows = await _db.query('tasks', orderBy: 'id ASC');
    return rows
        .map(
          (row) => TaskModel(
            id: row['id'] as int,
            name: row['name'] as String,
            category: row['category'] as String,
            timerTime: row['timer_time'] as String,
            state: _parseTaskState(row['state'] as String),
          ),
        )
        .toList();
  }

  Future<void> updateTaskState(int taskId, TaskState state) async {
    await _db.update(
      'tasks',
      {'state': _taskStateToStorageValue(state)},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> upsertTask({
    required String name,
    required String category,
    required int duration,
    int? remoteId,
    String state = 'pending',
    int rewardPoints = 3,
  }) async {
    final now = DateTime.now().toIso8601String();
    final timerTime = _formatDurationMinutesToTimerTime(duration);
    await _db.insert('tasks', {
      'remote_id': remoteId,
      'name': name,
      'category': category,
      'timer_time': timerTime,
      'duration': duration,
      'state': state,
      'reward_points': rewardPoints,
      'completed_at': null,
      'created': now,
      'updated': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _formatDurationMinutesToTimerTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h${mins > 0 ? '${mins}m' : ''}';
    }
    return '${minutes}m';
  }

  Future<void> syncCloudTasks(List<Map<String, dynamic>> cloudTasks) async {
    await _db.delete('tasks');

    for (final task in cloudTasks) {
      await upsertTask(
        name: task['name'] ?? '',
        category: task['category'] ?? 'Chore',
        duration: _asInt(task['duration']),
        remoteId: _asNullableInt(task['id']),
        state: task['state'] ?? 'pending',
        rewardPoints: _asInt(task['reward_points'], fallback: 3),
      );
    }
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int completedTasksSync(List<TaskModel> tasks) =>
      tasks.where((t) => t.state == TaskState.completed).length;

  static TaskState _parseTaskState(String state) {
    switch (state) {
      case 'accepted':
        return TaskState.accepted;
      case 'in_progress':
      case 'inProgress':
        return TaskState.inProgress;
      case 'completed':
        return TaskState.completed;
      default:
        return TaskState.initial;
    }
  }

  static String _taskStateToStorageValue(TaskState state) {
    switch (state) {
      case TaskState.accepted:
        return 'accepted';
      case TaskState.inProgress:
        return 'in_progress';
      case TaskState.completed:
        return 'completed';
      case TaskState.initial:
        return 'pending';
    }
  }

  // ── App Limits (SQLite) ───────────────────────────────────────────

  /// Returns the allowed minutes for a specific app, or `null` if no
  /// limit has been set for that package.
  Future<int?> getAppLimit(String packageName) async {
    final rows = await _db.query(
      'app_limits',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    if (rows.isEmpty) return null;
    return rows.first['allowed_minutes'] as int;
  }

  /// Returns all per-app limits as a map: packageName → allowedMinutes.
  Future<Map<String, int>> getAllAppLimits() async {
    final rows = await _db.query('app_limits');
    return {
      for (final row in rows)
        row['package_name'] as String: row['allowed_minutes'] as int,
    };
  }

  Future<void> setAppLimit(
    String packageName,
    String appName,
    int allowedMinutes,
  ) async {
    await _db.insert('app_limits', {
      'package_name': packageName,
      'app_name': appName,
      'allowed_minutes': allowedMinutes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeAppLimit(String packageName) async {
    await _db.delete(
      'app_limits',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  // ── Installed Apps (SQLite) ───────────────────────────────────────

  Future<void> upsertInstalledApps(
    List<Map<String, dynamic>> apps, {
    required String childHash,
  }) async {
    if (childHash.trim().isEmpty) return;

    final batch = _db.batch();
    for (final app in apps) {
      final packageName = (app['package_name'] as String?)?.trim() ?? '';
      final name =
          ((app['name'] ?? app['app_name']) as String?)?.trim() ?? packageName;

      if (packageName.isEmpty || name.isEmpty) continue;

      batch.insert('installed_apps', {
        'package_name': packageName,
        'name': name,
        'category': (app['category'] as String?)?.trim().isNotEmpty == true
            ? (app['category'] as String).trim()
            : 'not available',
        'created': (app['created'] as String?)?.trim().isNotEmpty == true
            ? (app['created'] as String).trim()
            : 'not available',
        'child_hash': childHash.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getInstalledApps({String? childHash}) {
    return _db.query(
      'installed_apps',
      where: childHash == null ? null : 'child_hash = ?',
      whereArgs: childHash == null ? null : [childHash],
      orderBy: 'name ASC',
    );
  }

  Future<void> deleteInstalledApp({
    required String packageName,
    required String childHash,
  }) async {
    final trimmedPackage = packageName.trim();
    final trimmedChildHash = childHash.trim();
    if (trimmedPackage.isEmpty || trimmedChildHash.isEmpty) return;

    await _db.delete(
      'installed_apps',
      where: 'package_name = ? AND child_hash = ?',
      whereArgs: [trimmedPackage, trimmedChildHash],
    );
  }

  // ── Local Usage Snapshots (SQLite) ───────────────────────────────

  Future<void> upsertLocalUsageSnapshot(
    List<Map<String, dynamic>> apps, {
    required String childHash,
    bool synced = false,
  }) async {
    if (childHash.trim().isEmpty) return;

    final batch = _db.batch();
    final recordedAt = DateTime.now().toIso8601String();

    for (final app in apps) {
      final packageName = (app['package_name'] as String?)?.trim() ?? '';
      final appName =
          ((app['app_name'] ?? app['name']) as String?)?.trim() ?? packageName;
      final foregroundMs = app['foreground_ms'] as int? ?? 0;
      final opens = app['opens'] as int? ?? 0;

      if (packageName.isEmpty || appName.isEmpty) continue;

      batch.insert('local_app_usage', {
        'package_name': packageName,
        'app_name': appName,
        'foreground_ms': foregroundMs,
        'opens': opens,
        'recorded_at': recordedAt,
        'child_hash': childHash.trim(),
        'synced': synced ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // ── App Limits (SQLite) ──────────────────────────────────────────

  Future<void> saveAppLimits(List<Map<String, dynamic>> limits) async {
    print('saveAppLimits called with ${limits.length} items');

    final batch = _db.batch();

    for (final limit in limits) {
      final packageName = (limit['package_name'] as String?)?.trim() ?? '';
      final allowedMinutes = limit['limit_minutes'] as int? ?? 0;

      if (packageName.isEmpty) continue;

      final appRows = await _db.query(
        'installed_apps',
        columns: ['name'],
        where: 'package_name = ?',
        whereArgs: [packageName],
        limit: 1,
      );

      String appName = packageName;
      if (appRows.isNotEmpty) {
        final storedName = appRows.first['name'] as String?;
        if (storedName != null && storedName.isNotEmpty) {
          appName = storedName;
        }
      }

      print(
        'Inserting: package=$packageName, appName=$appName, minutes=$allowedMinutes',
      );

      batch.insert('app_limits', {
        'package_name': packageName,
        'app_name': appName,
        'allowed_minutes': allowedMinutes,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    print('saveAppLimits completed');
  }

  Future<void> clearAppLimits() async {
    await _db.delete('app_limits');
    print('Cleared all app limits from local DB');
  }

  Future<void> markLocalUsageSynced({required String childHash}) async {
    await _db.update(
      'local_app_usage',
      {'synced': 1, 'recorded_at': DateTime.now().toIso8601String()},
      where: 'child_hash = ?',
      whereArgs: [childHash],
    );
  }

  // ── Chat Messages (SQLite) ───────────────────────────────────────────

  Future<List<ChatMessage>> getChatMessages() async {
    final rows = await _db.query('chat_messages', orderBy: 'time ASC');
    return rows.map((row) => ChatMessage.fromMap(row)).toList();
  }

  Future<void> sendChatMessage(String text) async {
    await _db.insert('chat_messages', {
      'text': text,
      'time': DateTime.now().toIso8601String(),
      'is_me': 1,
      'is_seen': 1,
    });
  }

  Future<void> markMessagesAsSeen() async {
    await _db.update(
      'chat_messages',
      {'is_seen': 1},
      where: 'is_me = ? AND is_seen = ?',
      whereArgs: [0, 0],
    );
  }

  Future<int> getUnreadCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM chat_messages WHERE is_me = 0 AND is_seen = 0',
    );
    return rows.first['count'] as int;
  }
}
//  PARENT DATA
// ═══════════════════════════════════════════════════════════════════════

/// Placeholder partition for parent-side data (profiles, rules, etc.).
class ParentData {
  // Will be populated as parent features are built out.
}
