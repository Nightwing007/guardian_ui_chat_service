import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/set_screen_time_bottom_sheet.dart';
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
  Map<int, Map<String, dynamic>> _appLimits = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final installedAppsResult = await AuthService().getInstalledApps(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    );

    final appLimitsResult = await AuthService().getAppLimits(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    );

    if (!mounted) return;

    if (installedAppsResult['success']) {
      final appsData = installedAppsResult['data'] as List<dynamic>;
      _apps = appsData.map((app) {
        return {
          'id': app['id'] ?? 0,
          'package_name': app['package_name'] ?? '',
          'app_name': app['app_name'] ?? '',
          'icon_bytes': app['icon_bytes'],
        };
      }).toList();
    }

    if (appLimitsResult['success']) {
      final limitsData = appLimitsResult['data'] as List<dynamic>;
      _appLimits = {};
      for (final limit in limitsData) {
        final installedAppId = limit['installed_app'] as int?;
        if (installedAppId != null) {
          _appLimits[installedAppId] = {
            'id': limit['id'],
            'limit_minutes': limit['limit_minutes'] ?? 0,
            'is_active': limit['is_active'] ?? true,
          };
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _updateAppLimit(int appId, String appName, int? currentLimitId, int limitMinutes) async {
    if (currentLimitId != null) {
      await AuthService().updateAppLimit(
        email: widget.email,
        password: widget.password,
        childHash: widget.childHash,
        limitId: currentLimitId,
        limitMinutes: limitMinutes,
        isActive: true,
      );
    } else {
      await AuthService().createAppLimit(
        email: widget.email,
        password: widget.password,
        childHash: widget.childHash,
        installedAppId: appId,
        limitMinutes: limitMinutes,
      );
    }
    await _loadData();
  }

  Future<void> _deleteAppLimit(int appId, int limitId) async {
    await AuthService().deleteAppLimit(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
      limitId: limitId,
    );
    await _loadData();
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
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
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

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                  : _apps.isEmpty
                      ? Center(
                          child: Text(
                            'No installed apps found',
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _apps.length,
                          itemBuilder: (context, index) {
                            final item = _apps[index];
                            final appId = item['id'] as int;
                            final limitInfo = _appLimits[appId];
                            final limitMinutes = limitInfo?['limit_minutes'] as int? ?? 0;
                            final limitId = limitInfo?['id'] as int?;
                            final limitText = limitMinutes > 0 
                                ? '${(limitMinutes / 60).floor()}hr ${limitMinutes % 60}m' 
                                : 'No limit';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        (item['app_name'] as String).isNotEmpty 
                                            ? (item['app_name'] as String)[0].toUpperCase() 
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['app_name'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          limitText,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final hours = limitMinutes > 0 ? limitMinutes ~/ 60 : 0;
                                      final newDuration = await showModalBottomSheet<Duration>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => SetScreenTimeBottomSheet(
                                          title: item['app_name'] as String,
                                          initialDuration: Duration(minutes: limitMinutes),
                                        ),
                                      );

                                      if (newDuration != null) {
                                        await _updateAppLimit(
                                          appId,
                                          item['app_name'] as String,
                                          limitId,
                                          newDuration.inMinutes,
                                        );
                                      }
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: AppColors.cmdIconBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, color: Color(0xFF2B2B2B), size: 18),
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
}
