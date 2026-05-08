import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/custom_bottom_nav_bar.dart';
import 'package:myapp/widgets/child/buy_additional_time_dialog.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/child/app_usage_service.dart';
import 'package:myapp/services/child/app_icon_cache.dart';
import 'package:myapp/services/session_service.dart';
class ScreenTimeScreen extends StatefulWidget {
  final int currentNavIndex;
  final ValueChanged<int> onNavTap;

  const ScreenTimeScreen({
    super.key,
    required this.currentNavIndex,
    required this.onNavTap,
  });

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  final _db = AppDatabase();
  final _appIconCache = AppIconCache();
  Map<String, int> _appLimits = {};
  int _allowedScreenTimeMinutes = 240;
  int _totalPoints = 10;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _appIconCache.preloadApps();
    _refreshUsage();
    _loadAppLimits();
    _loadSettings();
  }

  Future<void> _refreshUsage() async {
    await _db.child.refreshUsageData();
    if (mounted) setState(() {});
  }

  Future<void> _loadAppLimits() async {
    final limits = await _db.child.getAllAppLimits();
    if (mounted) setState(() => _appLimits = limits);
  }

  Future<void> _loadSettings() async {
    final allowed = await _db.child.getTotalAllowedScreenTimeMinutes();
    final points = await _db.child.getTotalPoints();
    if (mounted) {
      setState(() {
        _allowedScreenTimeMinutes = allowed;
        _totalPoints = points;
      });
    }
  }

  Future<void> _refreshAppLimits() async {
    setState(() => _isRefreshing = true);
    try {
      await AppDatabase().child.clearAppLimits();

      final session = await SessionService.getChildSession();
      final deviceToken = session['deviceToken'] as String?;
      final childHash = session['childHash'] as String?;

      if (deviceToken == null || childHash == null) return;

      final result = await AuthService().getChildAppLimits(
        childHash: childHash,
        deviceToken: deviceToken,
      );

      if (result['success'] == true && result['data'] is Map) {
        final data = result['data'] as Map<String, dynamic>;
        final limits = data['limits'] as List?;
        if (limits != null) {
          print('Got ${limits.length} limits from cloud');
          final limitsList = limits
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          print('Limits list: $limitsList');
          await AppDatabase().child.saveAppLimits(limitsList);
          print('Saved to local DB, now loading...');
          await _loadAppLimits();
          print('Loaded app limits: $_appLimits');
        }
      }
    } catch (e) {
      print('Error refreshing app limits: $e');
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '<1m';
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg-app.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Screen Time',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Your Screen Insights',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
          titleSpacing: 0,
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScreenTimeCard(),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Usage and Limitations',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isRefreshing ? null : _refreshAppLimits,
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentBlue,
                              ),
                            )
                          : const Icon(
                              Icons.refresh,
                              color: AppColors.accentBlue,
                              size: 24,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildAppsList(),
                const SizedBox(height: 120), // Padding for bottom nav
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: widget.currentNavIndex,
          onTap: (index) {
            widget.onNavTap(index);
            Navigator.of(context).pop(); // Go back to main and change tab
          },
        ),
      ),
    );
  }

  Widget _buildScreenTimeCard() {
    final child = _db.child;
    final limitHours = _allowedScreenTimeMinutes / 60.0;
    final usedHours = child.totalUsedScreenTime.inMinutes / 60.0;
    final percent = (usedHours / limitHours).clamp(0.0, 1.0);
    final screenTimeText = _formatDuration(child.totalUsedScreenTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.tertiaryGradientStart, AppColors.tertiaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SCREEN TIME',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularPercentIndicator(
                radius: 75.0,
                lineWidth: 12.0,
                percent: percent,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      screenTimeText,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "OF ${limitHours.toInt()}H LIMIT",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const BuyAdditionalTimeDialog(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.tertiaryGradientEnd,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                progressColor: percent >= 1.0 ? Colors.redAccent : AppColors.accentBlue,
                backgroundColor: const Color(0xFF1E2D4A),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _totalPoints.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    "Points Left",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAppsList() {
    final child = _db.child;

    if (child.isUsageLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue),
        ),
      );
    }

    final appsWithLimits = _appLimits.keys.take(10).toList();

    if (appsWithLimits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            'No apps with limits set yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textGrey,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          for (int i = 0; i < appsWithLimits.length; i++) ...[
            _buildAppLimitItem(packageName: appsWithLimits[i]),
            if (i < appsWithLimits.length - 1) _buildDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: Colors.grey.shade800, thickness: 1),
    );
  }

  Widget _buildRealAppUsageItem({required AppUsageInfo app}) {
    String displayName = app.appName;
    if (displayName.contains('.')) {
      displayName = displayName.split('.').last;
    }

    final allowedMinutes = _appLimits[app.packageName];
    final usedHours = app.totalTimeInForeground.inMinutes / 60.0;
    
    String timeString;
    bool hasLimit = allowedMinutes != null;
    
    if (hasLimit) {
      final allowedHours = allowedMinutes / 60;
      timeString = '${usedHours.toStringAsFixed(1)}hr / ${allowedHours.toStringAsFixed(1)}hr';
    } else {
      timeString = _formatDuration(app.totalTimeInForeground);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _appIconCache.getAppIconWidget(app.packageName, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  timeString,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          if (hasLimit)
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => BuyAdditionalTimeDialog(appName: displayName),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.sosRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLimitItem({required String packageName}) {
    final allowedMinutes = _appLimits[packageName] ?? 0;
    final child = _db.child;
    final usageApp = child.appUsageList.where((a) => a.packageName == packageName).firstOrNull;
    
    String displayName = packageName.split('.').last;
    if (usageApp != null && usageApp.appName.isNotEmpty) {
      displayName = usageApp.appName.contains('.') 
          ? usageApp.appName.split('.').last 
          : usageApp.appName;
    }

    String timeString;
    if (usageApp != null) {
      final usedHours = usageApp.totalTimeInForeground.inMinutes / 60.0;
      final allowedHours = allowedMinutes / 60;
      timeString = '${usedHours.toStringAsFixed(1)}hr / ${allowedHours.toStringAsFixed(1)}hr';
    } else {
      timeString = '0hr / ${(allowedMinutes / 60).toStringAsFixed(1)}hr';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _appIconCache.getAppIconWidget(packageName, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  timeString,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => BuyAdditionalTimeDialog(appName: displayName),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.sosRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
