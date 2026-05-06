# App Usage, Screen Time & Blocker — Full Source Code

---

## File 1: `lib/services/app_usage_service.dart`

**Role:** Service layer — communicates with native Android via `MethodChannel('guardian/monitoring')` to fetch usage stats, manage limits, and control the blocker service.

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────

class AppUsageInfo {
  final String packageName;
  final String appName;
  final Duration totalTimeInForeground;
  final DateTime lastTimeUsed;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.totalTimeInForeground,
    required this.lastTimeUsed,
  });

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      totalTimeInForeground: Duration(
        milliseconds: (map['totalTimeInForeground'] as num?)?.toInt() ?? 0,
      ),
      lastTimeUsed: DateTime.fromMillisecondsSinceEpoch(
        (map['lastTimeUsed'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  String toString() =>
      'AppUsageInfo($appName, ${totalTimeInForeground.inMinutes}m)';
}

class DailyScreenTime {
  final DateTime date;
  final Duration totalTime;

  DailyScreenTime({required this.date, required this.totalTime});

  factory DailyScreenTime.fromMap(Map<dynamic, dynamic> map) {
    return DailyScreenTime(
      date: DateTime.fromMillisecondsSinceEpoch(
        (map['date'] as num?)?.toInt() ?? 0,
      ),
      totalTime: Duration(
        milliseconds: (map['totalTime'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class AppLaunchEvent {
  final String packageName;
  final DateTime timestamp;

  AppLaunchEvent({required this.packageName, required this.timestamp});

  factory AppLaunchEvent.fromMap(Map<dynamic, dynamic> map) {
    return AppLaunchEvent(
      packageName: map['packageName'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// App Usage Service
// ─────────────────────────────────────────────────────────

class AppUsageService {
  AppUsageService._();
  static final AppUsageService instance = AppUsageService._();

  static const _methodChannel = MethodChannel('guardian/monitoring');
  static const _appLaunchChannel = EventChannel('guardian/app_launch_stream');

  Stream<AppLaunchEvent>? _appLaunchStream;

  // ── Permission checks ──

  Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _methodChannel.invokeMethod('hasUsageStatsPermission');
      debugPrint('[AppUsageService] hasUsageStatsPermission raw result: $result (${result.runtimeType})');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] hasUsageStatsPermission error: $e');
      return false;
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _methodChannel.invokeMethod('openUsageAccessSettings');
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] openUsageAccessSettings error: $e');
    }
  }

  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _methodChannel.invokeMethod('hasOverlayPermission');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] requestOverlayPermission error: $e');
    }
  }

  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isAccessibilityEnabled');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] openAccessibilitySettings error: $e');
    }
  }

  // ── Usage stats ──

  Future<List<AppUsageInfo>> getTodayUsage() async {
    try {
      final result = await _methodChannel.invokeMethod('getTodayUsageStats');
      debugPrint('[AppUsageService] getTodayUsage raw result type: ${result.runtimeType}');

      if (result == null) {
        debugPrint('[AppUsageService] getTodayUsage: result is null');
        return [];
      }

      if (result is! List) {
        debugPrint('[AppUsageService] getTodayUsage: result is NOT a List, it is ${result.runtimeType}: $result');
        return [];
      }

      debugPrint('[AppUsageService] getTodayUsage: got ${result.length} items');

      final apps = <AppUsageInfo>[];
      for (int i = 0; i < result.length; i++) {
        final item = result[i];
        if (item is Map) {
          try {
            final app = AppUsageInfo.fromMap(item);
            apps.add(app);
            if (i < 10) {
              debugPrint('[AppUsageService]   ${app.appName}: ${app.totalTimeInForeground.inMinutes}m');
            }
          } catch (e) {
            debugPrint('[AppUsageService] Error parsing item $i: $e, raw: $item');
          }
        } else {
          debugPrint('[AppUsageService] Item $i is not a Map: ${item.runtimeType}');
        }
      }
      return apps;
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] getTodayUsage PlatformException: $e');
      return [];
    } catch (e) {
      debugPrint('[AppUsageService] getTodayUsage unexpected error: $e');
      return [];
    }
  }

  Future<List<AppUsageInfo>> getWeeklyUsage() async {
    try {
      final result = await _methodChannel.invokeMethod('getWeeklyUsageStats');
      if (result == null || result is! List) return [];
      return (result)
          .whereType<Map>()
          .map((e) => AppUsageInfo.fromMap(e))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] getWeeklyUsage error: $e');
      return [];
    }
  }

  Future<List<DailyScreenTime>> getWeeklyDailyBreakdown() async {
    try {
      final result = await _methodChannel.invokeMethod('getWeeklyDailyBreakdown');
      debugPrint('[AppUsageService] getWeeklyDailyBreakdown raw result type: ${result.runtimeType}');

      if (result == null || result is! List) {
        debugPrint('[AppUsageService] getWeeklyDailyBreakdown: not a List');
        return [];
      }

      debugPrint('[AppUsageService] getWeeklyDailyBreakdown: ${result.length} days');

      return (result)
          .whereType<Map>()
          .map((e) => DailyScreenTime.fromMap(e))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] getWeeklyDailyBreakdown error: $e');
      return [];
    }
  }

  // ── App limits ──

  Future<void> setAppLimit(String packageName, Duration limit) async {
    try {
      await _methodChannel.invokeMethod('setAppLimit', {
        'packageName': packageName,
        'limitMs': limit.inMilliseconds,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to set app limit: ${e.message}');
    }
  }

  Future<void> removeAppLimit(String packageName) async {
    try {
      await _methodChannel.invokeMethod('removeAppLimit', {
        'packageName': packageName,
      });
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] removeAppLimit error: $e');
    }
  }

  Future<Map<String, Duration>> getAppLimits() async {
    try {
      final result = await _methodChannel.invokeMethod('getAppLimits');
      if (result == null || result is! Map) return {};
      return (result as Map<dynamic, dynamic>).map((key, value) => MapEntry(
            key as String,
            Duration(milliseconds: (value as num).toInt()),
          ));
    } on PlatformException {
      return {};
    }
  }

  // ── Blocker service ──

  Future<void> startBlocker() async {
    await _methodChannel.invokeMethod('startBlocker');
  }

  Future<void> stopBlocker() async {
    await _methodChannel.invokeMethod('stopBlocker');
  }

  Future<bool> isBlockerRunning() async {
    try {
      final result = await _methodChannel.invokeMethod('isBlockerRunning');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  // ── App launch stream ──

  Stream<AppLaunchEvent> get appLaunchStream {
    _appLaunchStream ??= _appLaunchChannel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['packageName'] != null)
        .map((event) => AppLaunchEvent.fromMap(event))
        .asBroadcastStream();
    return _appLaunchStream!;
  }
}
```

---

## File 2: `lib/screens/app_usage_screen.dart`

**Role:** UI layer — displays screen time, per-app usage, weekly chart, blocker toggle, and limit management.

```dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/app_usage_service.dart';

// ─────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────

const _bg = Color(0xFF0F0F1A);
const _surface = Color(0xFF1A1A2E);
const _purple = Color(0xFF6C63FF);
const _teal = Color(0xFF03DAC6);
const _amber = Color(0xFFFFB74D);
const _red = Color(0xFFFF4D6D);
const _green = Color(0xFF4CAF50);

// ─────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({super.key});

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen>
    with TickerProviderStateMixin {
  final _service = AppUsageService.instance;

  bool _hasPermission = false;
  bool _loading = true;
  bool _blockerRunning = false;

  List<AppUsageInfo> _todayUsage = [];
  List<DailyScreenTime> _weeklyBreakdown = [];
  Map<String, Duration> _appLimits = {};

  Duration _totalScreenTime = Duration.zero;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    debugPrint('[AppUsageScreen] _loadData started');
    setState(() => _loading = true);

    final hasPermission = await _service.hasUsageStatsPermission();
    debugPrint('[AppUsageScreen] hasPermission: $hasPermission');
    if (!hasPermission) {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
      return;
    }

    final today = await _service.getTodayUsage();
    debugPrint('[AppUsageScreen] Loaded ${today.length} apps for today');

    final weekly = await _service.getWeeklyDailyBreakdown();
    debugPrint(
        '[AppUsageScreen] Loaded ${weekly.length} days for weekly breakdown');

    final limits = await _service.getAppLimits();
    final blockerRunning = await _service.isBlockerRunning();

    final totalMs = today.fold<int>(
      0,
      (sum, app) => sum + app.totalTimeInForeground.inMilliseconds,
    );

    if (mounted) {
      setState(() {
        _hasPermission = true;
        _todayUsage = today;
        _weeklyBreakdown = weekly;
        _appLimits = limits;
        _blockerRunning = blockerRunning;
        _totalScreenTime = Duration(milliseconds: totalMs);
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
      debugPrint('[AppUsageScreen] UI state updated');
    }
  }

  // ─────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isWarning ? _amber.withOpacity(0.9) : _green.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _requestPermission() async {
    await _service.openUsageAccessSettings();
    _showSnack('Enable "Usage Access" for Guardian AI', isWarning: true);
    // Poll for permission
    Future.delayed(const Duration(seconds: 3), () async {
      final granted = await _service.hasUsageStatsPermission();
      if (granted && mounted) _loadData();
    });
  }

  Future<void> _toggleBlocker() async {
    if (_blockerRunning) {
      await _service.stopBlocker();
      setState(() => _blockerRunning = false);
      _showSnack('App blocker stopped');
    } else {
      final accessibilityEnabled = await _service.isAccessibilityEnabled();
      if (!accessibilityEnabled) {
        await _service.openAccessibilitySettings();
        _showSnack('Enable Accessibility for real-time app blocking.', isWarning: true);
        return;
      }

      await _service.startBlocker();
      setState(() => _blockerRunning = true);
      _showSnack('✅ App blocker active (limits will auto-block apps)');
    }
  }

  void _showSetLimitSheet(AppUsageInfo app) {
    final existingLimit = _appLimits[app.packageName];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SetLimitSheet(
        appName: app.appName,
        packageName: app.packageName,
        currentUsage: app.totalTimeInForeground,
        existingLimit: existingLimit,
        initialBlockerRunning: _blockerRunning,
        onSetLimit: (duration, enableBlocker) async {
          await _service.setAppLimit(app.packageName, duration);
          if (enableBlocker && !_blockerRunning) {
            final accessibilityEnabled = await _service.isAccessibilityEnabled();
            if (!accessibilityEnabled) {
              await _service.openAccessibilitySettings();
              _showSnack(
                'Limit saved. Enable Accessibility to enforce blocking.',
                isWarning: true,
              );
              Navigator.of(ctx).pop();
              await _loadData();
              return;
            }
            await _service.startBlocker();
          }
          Navigator.of(ctx).pop();
          await _loadData();
          if (enableBlocker) {
            _showSnack('✅ Limit set for ${app.appName} and blocker activated');
          } else {
            _showSnack('✅ Limit set for ${app.appName}');
          }
        },
        onRemoveLimit: existingLimit != null
            ? () async {
                await _service.removeAppLimit(app.packageName);
                Navigator.of(ctx).pop();
                _loadData();
                _showSnack('Limit removed for ${app.appName}');
              }
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _purple),
            )
          : !_hasPermission
              ? _buildPermissionRequest()
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: _purple,
                    child: CustomScrollView(
                      slivers: [
                        _buildAppBar(),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildScreenTimeHeader(),
                                const SizedBox(height: 20),
                                _buildWeeklyChart(),
                                const SizedBox(height: 24),
                                _buildBlockerToggle(),
                                const SizedBox(height: 24),
                                _buildSectionLabel('📱 App Usage Today'),
                                const SizedBox(height: 10),
                                _buildAppList(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // App Bar
  // ─────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _surface,
      expandedHeight: 100,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_purple, Color(0xFF3D5AFE)],
                ),
              ),
              child: const Icon(Icons.timer_outlined,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Screen Time',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Permission request
  // ─────────────────────────────────────────────────────────

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_purple, Color(0xFF3D5AFE)],
                ),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Usage Access Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'To track app usage like Digital Wellbeing, Guardian AI needs permission to access usage statistics.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Grant Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Screen time header
  // ─────────────────────────────────────────────────────────

  Widget _buildScreenTimeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _purple.withOpacity(0.15),
            const Color(0xFF3D5AFE).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, color: _purple, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Screen time',
                  style: TextStyle(
                    color: _purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: _purple, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_totalScreenTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Today',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Weekly chart
  // ─────────────────────────────────────────────────────────

  Widget _buildWeeklyChart() {
    if (_weeklyBreakdown.isEmpty) return const SizedBox.shrink();

    final maxMs = _weeklyBreakdown
        .map((d) => d.totalTime.inMilliseconds)
        .reduce(math.max)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: _purple, size: 18),
              const SizedBox(width: 8),
              const Text(
                'This Week',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_weeklyBreakdown.length, (i) {
                final day = _weeklyBreakdown[i];
                final isToday = i == _weeklyBreakdown.length - 1;
                final fraction =
                    maxMs > 0 ? day.totalTime.inMilliseconds / maxMs : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Time label above bar
                        if (fraction > 0.05)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _formatDurationShort(day.totalTime),
                              style: TextStyle(
                                color: isToday ? _purple : Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          height: (130 * fraction).clamp(4.0, 130.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: isToday
                                ? const LinearGradient(
                                    colors: [_purple, Color(0xFF3D5AFE)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : null,
                            color: isToday ? null : _purple.withOpacity(0.25),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Day label
                        Text(
                          _dayLabel(day.date),
                          style: TextStyle(
                            color: isToday ? Colors.white : Colors.white38,
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Blocker toggle
  // ─────────────────────────────────────────────────────────

  Widget _buildBlockerToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _blockerRunning
              ? _green.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
        ),
        boxShadow: _blockerRunning
            ? [
                BoxShadow(
                  color: _green.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purple, Color(0xFF3D5AFE)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.block_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Blocker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _blockerRunning ? _green : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _blockerRunning ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: _blockerRunning ? _green : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_appLimits.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        '${_appLimits.length} limit${_appLimits.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: _blockerRunning,
            onChanged: (_) => _toggleBlocker(),
            activeColor: _teal,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // App list
  // ─────────────────────────────────────────────────────────

  Widget _buildAppList() {
    if (_todayUsage.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: const Column(
          children: [
            Icon(Icons.phone_android_rounded, color: Colors.white24, size: 36),
            SizedBox(height: 12),
            Text(
              'No app usage recorded today',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _todayUsage.length.clamp(0, 25),
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.06),
          height: 1,
        ),
        itemBuilder: (ctx, i) {
          final app = _todayUsage[i];
          final limit = _appLimits[app.packageName];
          return _AppUsageTile(
            app: app,
            limit: limit,
            maxDuration: _todayUsage.isNotEmpty
                ? _todayUsage.first.totalTimeInForeground
                : const Duration(hours: 1),
            onTapTimer: () => _showSetLimitSheet(app),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDurationShort(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}

// ─────────────────────────────────────────────────────────
// App Usage Tile
// ─────────────────────────────────────────────────────────

class _AppUsageTile extends StatelessWidget {
  final AppUsageInfo app;
  final Duration? limit;
  final Duration maxDuration;
  final VoidCallback onTapTimer;

  const _AppUsageTile({
    required this.app,
    required this.limit,
    required this.maxDuration,
    required this.onTapTimer,
  });

  @override
  Widget build(BuildContext context) {
    final isOverLimit = limit != null && app.totalTimeInForeground >= limit!;
    final usageFraction = maxDuration.inMilliseconds > 0
        ? (app.totalTimeInForeground.inMilliseconds /
                maxDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final barColor = isOverLimit ? _red : _purple;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _appColor(app.packageName),
                  _appColor(app.packageName).withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDuration(app.totalTimeInForeground),
                      style: TextStyle(
                        color: isOverLimit ? _red : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: usageFraction,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (limit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isOverLimit
                          ? '⏰ Over limit (${_formatDuration(limit!)})'
                          : 'Limit: ${_formatDuration(limit!)}',
                      style: TextStyle(
                        color: isOverLimit ? _red : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timer button
          InkWell(
            onTap: onTapTimer,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: limit != null
                    ? _purple.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: limit != null
                      ? _purple.withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                limit != null ? Icons.timer : Icons.timer_outlined,
                color: limit != null ? _purple : Colors.white38,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '<1m';
  }

  Color _appColor(String packageName) {
    final hash = packageName.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.4).toColor();
  }
}

// ─────────────────────────────────────────────────────────
// Set Limit Bottom Sheet
// ─────────────────────────────────────────────────────────

class _SetLimitSheet extends StatefulWidget {
  final String appName;
  final String packageName;
  final Duration currentUsage;
  final Duration? existingLimit;
  final bool initialBlockerRunning;
  final Future<void> Function(Duration duration, bool enableBlocker) onSetLimit;
  final VoidCallback? onRemoveLimit;

  const _SetLimitSheet({
    required this.appName,
    required this.packageName,
    required this.currentUsage,
    required this.existingLimit,
    required this.initialBlockerRunning,
    required this.onSetLimit,
    this.onRemoveLimit,
  });

  @override
  State<_SetLimitSheet> createState() => _SetLimitSheetState();
}

class _SetLimitSheetState extends State<_SetLimitSheet> {
  int _selectedIndex = -1;
  late bool _enableBlocker;

  final _presets = const [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
  ];

  @override
  void initState() {
    super.initState();
    _enableBlocker = widget.initialBlockerRunning;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            'Set daily limit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.appName,
            style: TextStyle(
                color: _purple, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Current usage: ${_formatDuration(widget.currentUsage)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 24),
          // Preset grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_presets.length, (i) {
              final preset = _presets[i];
              final isSelected = _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? _purple : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? _purple : Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _purple.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    _formatDuration(preset),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block_rounded, color: _teal, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Enable App Blocker with this limit',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Switch(
                  value: _enableBlocker,
                  onChanged: (v) => setState(() => _enableBlocker = v),
                  activeColor: _teal,
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Set button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIndex >= 0
                  ? () => widget.onSetLimit(
                      _presets[_selectedIndex], _enableBlocker)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Set Limit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Remove limit
          if (widget.onRemoveLimit != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: widget.onRemoveLimit,
              child: const Text(
                'Remove Limit',
                style: TextStyle(color: _red, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}
```

---

## File Summary

| File | Lines | Classes | Purpose |
|------|-------|---------|---------|
| `app_usage_service.dart` | 290 | `AppUsageInfo`, `DailyScreenTime`, `AppLaunchEvent`, `AppUsageService` | Native communication, usage data fetching, limit management, blocker control |
| `app_usage_screen.dart` | 1097 | `AppUsageScreen`, `_AppUsageTile`, `_SetLimitSheet` | UI for screen time, weekly chart, app list, blocker toggle, limit setting |

### Key Native Methods Called

| Method | Purpose |
|--------|---------|
| `hasUsageStatsPermission` | Check if usage stats access is granted |
| `openUsageAccessSettings` | Open Android usage access settings |
| `hasOverlayPermission` | Check overlay/draw-over permission |
| `requestOverlayPermission` | Open overlay permission settings |
| `isAccessibilityEnabled` | Check if accessibility service is enabled |
| `openAccessibilitySettings` | Open accessibility settings |
| `getTodayUsageStats` | Fetch today's per-app usage |
| `getWeeklyUsageStats` | Fetch weekly per-app usage |
| `getWeeklyDailyBreakdown` | Fetch daily screen time totals |
| `setAppLimit` | Store a time limit (packageName + ms) |
| `removeAppLimit` | Remove a stored limit |
| `getAppLimits` | Fetch all stored limits |
| `startBlocker` | Start native blocker service |
| `stopBlocker` | Stop native blocker service |
| `isBlockerRunning` | Check blocker status |

### Important Note

The **actual blocking enforcement** (detecting when an app exceeds its limit and blocking it) runs entirely on the **native Android side**. Flutter only sends commands (`startBlocker`, `setAppLimit`) and reads status (`isBlockerRunning`). The native Android code handles:
- Monitoring foreground app in real-time
- Comparing usage time against stored limits
- Showing blocking overlay or killing the app process
- Persisting limits across reboots
