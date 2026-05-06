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
      version: 3,
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
        total_allowed_screen_time_minutes INTEGER NOT NULL DEFAULT 240,
        total_points INTEGER NOT NULL DEFAULT 10
      )
    ''');
    await db.insert('child_settings', {
      'id': 1,
      'total_allowed_screen_time_minutes': 600,
      'total_points': 10,
    });

    // ── tasks ──
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        timer_time TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'initial'
      )
    ''');

    // Seed tasks from the bundled JSON asset.
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/tasks.json');
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

    // Seed per-app limits — only specific apps get a limit.
    const seedLimits = [
      {
        'package_name': 'com.whatsapp',
        'app_name': 'WhatsApp',
        'allowed_minutes': 180,
      },
      {
        'package_name': 'com.instagram.android',
        'app_name': 'Instagram',
        'allowed_minutes': 300,
      },
      {
        'package_name': 'com.google.android.youtube',
        'app_name': 'YouTube',
        'allowed_minutes': 120,
      },
      {
        'package_name': 'com.zhiliaoapp.musically',
        'app_name': 'TikTok',
        'allowed_minutes': 90,
      },
    ];
    for (final limit in seedLimits) {
      await db.insert('app_limits', limit);
    }

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
      {'text': 'Hey Alex! How was thr your day?', 'time': now.subtract(const Duration(hours: 2)).toIso8601String(), 'is_me': 0, 'is_seen': 1},
      {'text': 'It was good! I finished my homework.', 'time': now.subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(), 'is_me': 1, 'is_seen': 1},
      {'text': 'That\'s great! Keep it up!', 'time': now.subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(), 'is_me': 0, 'is_seen': 1},
      {'text': 'Thanks Mom! Can I have more screen time?', 'time': now.subtract(const Duration(hours: 1)).toIso8601String(), 'is_me': 1, 'is_seen': 1},
      {'text': 'Complete your tasks first!', 'time': now.subtract(const Duration(minutes: 30)).toIso8601String(), 'is_me': 0, 'is_seen': 0},
    ];
    for (final msg in sampleMessages) {
      await db.insert('chat_messages', msg);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.update(
        'child_settings',
        {'total_allowed_screen_time_minutes': 600},
        where: 'id = 1',
      );
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
        {'text': 'Hey Alex! How was your day?', 'time': now.subtract(const Duration(hours: 2)).toIso8601String(), 'is_me': 0, 'is_seen': 1},
        {'text': 'It was good! I finished my homework.', 'time': now.subtract(const Duration(hours: 1, minutes: 45)).toIso8601String(), 'is_me': 1, 'is_seen': 1},
        {'text': 'That\'s great! Keep it up!', 'time': now.subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(), 'is_me': 0, 'is_seen': 1},
        {'text': 'Thanks Mom! Can I have more screen time?', 'time': now.subtract(const Duration(hours: 1)).toIso8601String(), 'is_me': 1, 'is_seen': 1},
        {'text': 'Complete your tasks first!', 'time': now.subtract(const Duration(minutes: 30)).toIso8601String(), 'is_me': 0, 'is_seen': 0},
      ];
      for (final msg in sampleMessages) {
        await db.insert('chat_messages', msg);
      }
    }
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

    final hasPermission =
        await _appUsageService.hasUsageStatsPermission();
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

  // ── Screen Time (SQLite) ──────────────────────────────────────────

  /// Total allowed screen time in minutes (from DB).
  Future<int> getTotalAllowedScreenTimeMinutes() async {
    final rows = await _db.query('child_settings', where: 'id = 1');
    if (rows.isEmpty) return 240;
    return rows.first['total_allowed_screen_time_minutes'] as int;
  }

  Future<void> setTotalAllowedScreenTimeMinutes(int minutes) async {
    await _db.update(
      'child_settings',
      {'total_allowed_screen_time_minutes': minutes},
      where: 'id = 1',
    );
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
    await _db.update(
      'child_settings',
      {'total_points': points},
      where: 'id = 1',
    );
  }

  Future<void> addPoints(int amount) async {
    final current = await getTotalPoints();
    await setTotalPoints(current + amount);
  }

  // ── Tasks (SQLite) ────────────────────────────────────────────────

  Future<List<TaskModel>> getTasks() async {
    final rows = await _db.query('tasks', orderBy: 'id ASC');
    return rows.map((row) => TaskModel(
      id: row['id'] as int,
      name: row['name'] as String,
      category: row['category'] as String,
      timerTime: row['timer_time'] as String,
      state: _parseTaskState(row['state'] as String),
    )).toList();
  }

  Future<void> updateTaskState(int taskId, TaskState state) async {
    await _db.update(
      'tasks',
      {'state': state.name},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  int completedTasksSync(List<TaskModel> tasks) =>
      tasks.where((t) => t.state == TaskState.completed).length;

  static TaskState _parseTaskState(String state) {
    switch (state) {
      case 'accepted':
        return TaskState.accepted;
      case 'completed':
        return TaskState.completed;
      default:
        return TaskState.initial;
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
      String packageName, String appName, int allowedMinutes) async {
    await _db.insert(
      'app_limits',
      {
        'package_name': packageName,
        'app_name': appName,
        'allowed_minutes': allowedMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeAppLimit(String packageName) async {
    await _db.delete(
      'app_limits',
      where: 'package_name = ?',
      whereArgs: [packageName],
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
