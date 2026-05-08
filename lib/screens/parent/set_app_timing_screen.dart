import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/set_screen_time_bottom_sheet.dart';
import 'package:myapp/services/parent/app_parent_database.dart';
import 'package:myapp/services/auth_service.dart';

class SetAppTimingScreen extends StatefulWidget {
  final String email;
  final String password;
  final String childHash;

  const SetAppTimingScreen({
    super.key,
    required this.email,
    required this.password,
    required this.childHash,
  });

  @override
  State<SetAppTimingScreen> createState() => _SetAppTimingScreenState();
}

class _SetAppTimingScreenState extends State<SetAppTimingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  final Map<String, int> _appLimits = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final result = await AuthService().getInstalledApps(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    );

    if (result['success'] == true && result['data'] is Map) {
      final data = result['data'] as Map<String, dynamic>;
      final installedApps = data['installed_apps'] as List?;
      if (installedApps != null) {
        final apps = installedApps
            .whereType<Map>()
            .map((app) => Map<String, dynamic>.from(app))
            .toList();

        await AppParentDatabase().upsertInstalledApps(
          childHash: widget.childHash,
          apps: apps,
        );
      }
    }

    final apps = await AppParentDatabase().getInstalledApps(
      childHash: widget.childHash,
    );

    final limits = await AppParentDatabase().getAppLimits(
      childHash: widget.childHash,
    );

    final limitsMap = <String, int>{};
    for (final limit in limits) {
      final packageName = limit['package_name'] as String?;
      final limitMinutes = limit['limit_minutes'] as int? ?? 0;
      if (packageName != null && packageName.isNotEmpty) {
        limitsMap[packageName] = limitMinutes;
      }
    }

    if (!mounted) return;

    final normalizedApps = apps.map(_normalizeApp).toList();
    setState(() {
      _apps = normalizedApps;
      _appLimits.clear();
      _appLimits.addAll(limitsMap);
      _filteredApps = _filterApps(normalizedApps, _searchQuery);
      _isLoading = false;
    });
  }

  Future<void> _saveAppLimit(String packageName, int limitMinutes, int? remoteId) async {
    await AppParentDatabase().upsertAppLimit(
      childHash: widget.childHash,
      packageName: packageName,
      remoteId: remoteId,
      limitMinutes: limitMinutes,
    );

    if (remoteId != null) {
      await AuthService().setAppLimit(
        email: widget.email,
        password: widget.password,
        childHash: widget.childHash,
        installedAppId: remoteId,
        limitMinutes: limitMinutes,
      );
    }

    setState(() {
      _appLimits[packageName] = limitMinutes;
    });
  }

  List<Map<String, dynamic>> _filterApps(List<Map<String, dynamic>> apps, String query) {
    if (query.isEmpty) return apps;
    final lowerQuery = query.toLowerCase();
    return apps.where((app) {
      final appName = (app['app_name'] as String? ?? '').toLowerCase();
      final packageName = (app['package_name'] as String? ?? '').toLowerCase();
      return appName.contains(lowerQuery) || packageName.contains(lowerQuery);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _filterApps(_apps, query);
    });
  }

  Map<String, dynamic> _normalizeApp(Map<String, dynamic> app) {
    final packageName = app['package_name']?.toString() ?? '';
    return {
      'id': _asInt(app['id']),
      'package_name': packageName,
      'app_name': _firstNonEmpty([
            app['app_name']?.toString(),
            app['name']?.toString(),
          ]) ??
          packageName,
      'icon_bytes': app['icon_bytes'],
      'category': app['category'],
    };
  }

  IconData _iconForPackage(String packageName) {
    const icons = [
      Icons.chat_bubble_rounded,
      Icons.photo_camera_rounded,
      Icons.public_rounded,
      Icons.play_arrow_rounded,
      Icons.music_note_rounded,
      Icons.sports_esports_rounded,
      Icons.school_rounded,
      Icons.apps_rounded,
    ];
    return icons[packageName.hashCode.abs() % icons.length];
  }

  Color _colorForPackage(String packageName) {
    const colors = [
      Color(0xFF00C853),
      Color(0xFFE1306C),
      Color(0xFF4285F4),
      Color(0xFFFF1744),
      Color(0xFF7C4DFF),
      Color(0xFFFFA000),
      Color(0xFF00B8D4),
      Color(0xFF64DD17),
    ];
    return colors[packageName.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Set App Timing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadData,
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(color: Color(0xFF888888)),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Color(0xFF888888)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                )
              : _filteredApps.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No apps found' : 'No apps found',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final item = _filteredApps[index];
                        final packageName = item['package_name'] as String;
                        final appName = item['app_name'] as String;
                        final remoteId = item['id'] as int?;
                        final limitMinutes = _appLimits[packageName] ?? 0;
                        final limitText = limitMinutes > 0
                            ? '${(limitMinutes / 60).floor()}hr ${limitMinutes % 60}m'
                            : 'No limit';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111314),
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _colorForPackage(packageName),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    _iconForPackage(packageName),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      limitText,
                                      style: const TextStyle(
                                        color: Color(0xFFC9C9C9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final newDuration =
                                      await showModalBottomSheet<Duration>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            SetScreenTimeBottomSheet(
                                              title: appName,
                                              initialDuration: Duration(
                                                minutes: limitMinutes,
                                              ),
                                            ),
                                      );

                                  if (newDuration != null) {
                                    _saveAppLimit(
                                      packageName,
                                      newDuration.inMinutes,
                                      remoteId,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE4E4E4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF2B2B2B),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
