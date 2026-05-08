import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _syncChildrenToLocalDb();
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
      await _syncInstalledAppsToLocalDb(children);
      await _syncUsageToLocalDb(children);
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
      final result = await AuthService().getInstalledApps(
        email: widget.email,
        password: widget.password,
        childHash: childHash,
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
          childHash: childHash,
          apps: apps,
        );
      }
    }
  }

  Future<void> _syncUsageToLocalDb(List<Map<String, dynamic>> children) async {
    for (final childHash in _childHashesFrom(children)) {
      final result = await AuthService().getChildUsage(
        email: widget.email,
        password: widget.password,
        childHash: childHash,
      );

      if (result['success'] == true && result['data'] is Map) {
        await AppParentDatabase().upsertChildUsage(
          childHash: childHash,
          usageData: Map<String, dynamic>.from(result['data'] as Map),
        );
      }
    }
  }

  Set<String> _childHashesFrom(List<Map<String, dynamic>> children) {
    final childHashes = children
        .map((child) => child['child_hash']?.toString().trim() ?? '')
        .where((childHash) => childHash.isNotEmpty)
        .toSet();

    if (childHashes.isEmpty && widget.childHash.trim().isNotEmpty) {
      childHashes.add(widget.childHash.trim());
    }

    return childHashes;
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

  // Placeholder screens for Parent
  List<Widget> get _screens => [
    ConnectScreen(
      onBack: () {
        setState(() {
          _currentIndex = 2; // Return to dashboard
        });
      },
    ),
    const AlertsScreen(),
    ParentDashboardScreen(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
      localCacheVersion: _localCacheVersion,
    ),
    CommandCenterScreen(
      onBack: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    ),
    ParentProfileScreen(
      email: widget.email,
      password: widget.password,
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
        ],
      ),
    );
  }
}
