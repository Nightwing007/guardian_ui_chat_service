import 'package:flutter/material.dart';
import 'package:myapp/screens/parent/parent_chat_screen.dart';
import 'package:myapp/screens/parent/parent_dashboard_screen.dart';
import 'package:myapp/screens/parent/alerts_screen.dart';
import 'package:myapp/screens/parent/command_center_screen.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/parent/connect_screen.dart';
import 'package:myapp/screens/parent/parent_profile_screen.dart';
import 'package:myapp/widgets/parent/parent_custom_bottom_nav.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/parent/app_parent_database.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/screens/welcome_screen.dart';

class ParentMainLayout extends StatefulWidget {
  final String email;
  final String password;
  final String childHash;

  const ParentMainLayout({
    super.key,
    required this.email,
    required this.password,
    required this.childHash,
  });

  @override
  State<ParentMainLayout> createState() => _ParentMainLayoutState();
}

class _ParentMainLayoutState extends State<ParentMainLayout> {
  int _currentIndex = 2; // Default to Dashboard (center)
  int _localCacheVersion = 0;
  String _selectedChildHash = '';
  String _selectedChildName = 'Child';
  bool _isSwitchingChild = false;

  @override
  void initState() {
    super.initState();
    _selectedChildHash = widget.childHash;
    _loadSelectedChild(notify: false);
    _syncChildrenToLocalDb();
  }

  Future<void> _loadSelectedChild({
    bool notify = true,
    bool syncSelectedData = false,
  }) async {
    final selectedChild = await AppParentDatabase().ensureSelectedChild(
      preferredChildHash: widget.childHash,
    );
    final selectedHash = selectedChild?['child_hash']?.toString() ?? '';
    final selectedName = _childName(selectedChild);

    if (selectedHash.isNotEmpty) {
      await SessionService.updateParentSelectedChild(selectedHash);
    }

    if (!mounted) return;
    setState(() {
      _selectedChildHash = selectedHash;
      _selectedChildName = selectedName;
      if (notify) _localCacheVersion++;
    });

    if (syncSelectedData && selectedHash.isNotEmpty) {
      await _syncSelectedChildData(selectedHash);
      if (mounted) {
        setState(() => _localCacheVersion++);
      }
    }
  }

  Future<void> _reloadForSelectedChild() async {
    if (_isSwitchingChild) return;

    if (mounted) {
      setState(() => _isSwitchingChild = true);
    }

    final selectedChild = await AppParentDatabase().ensureSelectedChild(
      preferredChildHash: _selectedChildHash,
    );
    final selectedHash = selectedChild?['child_hash']?.toString().trim() ?? '';
    if (selectedHash.isEmpty) {
      if (mounted) {
        setState(() => _isSwitchingChild = false);
      }
      return;
    }

    try {
      await SessionService.updateParentSelectedChild(selectedHash);
      await _syncSelectedChildData(selectedHash);
    } catch (e) {
      debugPrint('Failed to switch selected child: $e');
      if (mounted) {
        setState(() => _isSwitchingChild = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to switch child')));
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ParentMainLayout(
          email: widget.email,
          password: widget.password,
          childHash: selectedHash,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _syncChildrenToLocalDb() async {
    try {
      await AppParentDatabase().initialize();

      final result = await AuthService().getChildren(
        email: widget.email,
        password: widget.password,
      );

      if (result['success'] != true) return;

      final children = _extractChildren(result['data']);
      await AppParentDatabase().upsertChildren(children);
      await _loadSelectedChild(notify: false);
      await _syncInstalledAppsToLocalDb(children);
      await _syncUsageToLocalDb(children);
      await _syncTasksToLocalDb(children);
    } catch (e) {
      debugPrint('Failed to sync parent children to local DB: $e');
    } finally {
      if (mounted) {
        setState(() => _localCacheVersion++);
      }
    }
  }

  Future<void> _syncInstalledAppsToLocalDb(
    List<Map<String, dynamic>> children,
  ) async {
    for (final childHash in _childHashesFrom(children)) {
      await _syncInstalledAppsForChild(childHash);
    }
  }

  Future<void> _syncInstalledAppsForChild(String childHash) async {
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final result = await AuthService().getInstalledApps(
      email: widget.email,
      password: widget.password,
      childHash: trimmedChildHash,
    );

    if (result['success'] == true && result['data'] is Map) {
      final data = result['data'] as Map<String, dynamic>;
      final installedApps = data['installed_apps'] as List?;
      if (installedApps == null) return;

      final apps = installedApps
          .whereType<Map>()
          .map((app) => Map<String, dynamic>.from(app))
          .toList();

      await AppParentDatabase().upsertInstalledApps(
        childHash: trimmedChildHash,
        apps: apps,
      );
    }
  }

  Future<void> _syncUsageToLocalDb(List<Map<String, dynamic>> children) async {
    for (final childHash in _childHashesFrom(children)) {
      await _syncUsageForChild(childHash);
    }
  }

  Future<void> _syncUsageForChild(String childHash) async {
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final result = await AuthService().getChildUsage(
      email: widget.email,
      password: widget.password,
      childHash: trimmedChildHash,
    );

    if (result['success'] == true && result['data'] is Map) {
      await AppParentDatabase().upsertChildUsage(
        childHash: trimmedChildHash,
        usageData: Map<String, dynamic>.from(result['data'] as Map),
      );
    }
  }

  Future<void> _syncTasksToLocalDb(List<Map<String, dynamic>> children) async {
    for (final childHash in _childHashesFrom(children)) {
      await _syncTasksForChild(childHash);
    }
  }

  Future<void> _syncTasksForChild(String childHash) async {
    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) return;

    final result = await AuthService().getTasks(
      email: widget.email,
      password: widget.password,
      childHash: trimmedChildHash,
    );

    if (result['success'] != true || result['data'] is! Map) return;

    final data = result['data'] as Map<String, dynamic>;
    final cloudTasks = data['tasks'] as List<dynamic>?;
    if (cloudTasks == null) return;

    await AppParentDatabase().clearTasks(childHash: trimmedChildHash);

    for (final task in cloudTasks.whereType<Map>()) {
      final remoteId = _asNullableInt(task['id']);

      await AppParentDatabase().upsertTask(
        childHash: trimmedChildHash,
        name: task['name']?.toString() ?? '',
        category: task['category']?.toString() ?? 'Chore',
        duration: _asInt(task['duration']),
        remoteId: remoteId,
        state: task['state']?.toString() ?? 'pending',
        rewardPoints: _asInt(task['reward_points'], fallback: 3),
      );
    }
  }

  Future<void> _syncSelectedChildData(String childHash) async {
    await Future.wait([
      _syncInstalledAppsForChild(childHash),
      _syncUsageForChild(childHash),
      _syncTasksForChild(childHash),
    ]);
  }

  Set<String> _childHashesFrom(List<Map<String, dynamic>> children) {
    final childHashes = children
        .map((child) => child['child_hash']?.toString().trim() ?? '')
        .where((childHash) => childHash.isNotEmpty)
        .toSet();

    if (childHashes.isEmpty && _selectedChildHash.trim().isNotEmpty) {
      childHashes.add(_selectedChildHash.trim());
    } else if (childHashes.isEmpty && widget.childHash.trim().isNotEmpty) {
      childHashes.add(widget.childHash.trim());
    }

    return childHashes;
  }

  String _childName(Map<String, dynamic>? child) {
    final firstName = child?['first_name']?.toString().trim() ?? '';
    final lastName = child?['last_name']?.toString().trim() ?? '';
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Child' : name;
  }

  List<Map<String, dynamic>> _extractChildren(dynamic data) {
    final rawChildren = data is List
        ? data
        : data is Map
        ? data['children']
        : null;

    if (rawChildren is! List) return [];

    return rawChildren
        .whereType<Map>()
        .map((child) => Map<String, dynamic>.from(child))
        .toList();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Parent screens — indexed to match the bottom nav icons:
  // 0: Chat (msg icon), 1: Alerts, 2: Dashboard (center), 3: Command Center, 4: Profile
  List<Widget> get _screens => [
    // Index 0: Chat with the currently selected child
    ParentChatScreen(
      key: ValueKey('parent-chat-$_selectedChildHash'),
      childHash: _selectedChildHash,
      childName: _selectedChildName,
    ),
    // Index 1: Alerts
    const AlertsScreen(),
    // Index 2: Dashboard (centre button)
    ParentDashboardScreen(
      key: ValueKey('dashboard-$_selectedChildHash-$_localCacheVersion'),
      email: widget.email,
      password: widget.password,
      childHash: _selectedChildHash,
      childName: _selectedChildName,
      localCacheVersion: _localCacheVersion,
    ),
    // Index 3: Command Center
    CommandCenterScreen(
      key: ValueKey('command-$_selectedChildHash-$_localCacheVersion'),
      onBack: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      email: widget.email,
      password: widget.password,
      childHash: _selectedChildHash,
    ),
    // Index 4: Profile
    ParentProfileScreen(
      email: widget.email,
      password: widget.password,
      onChildrenChanged: _reloadForSelectedChild,
      onBack: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      onLogout: () async {
        await SessionService.clearParentSession();
        await AppParentDatabase().clearChildren();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Stack(
        children: [
          _screens[_currentIndex],

          // Custom Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ParentCustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
          if (_isSwitchingChild) const _SwitchingChildOverlay(),
        ],
      ),
    );
  }
}

class _SwitchingChildOverlay extends StatelessWidget {
  const _SwitchingChildOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: AppColors.scaffoldBackground,
          child: Center(
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryPurple),
                  SizedBox(height: 18),
                  Text(
                    'Switching child...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
