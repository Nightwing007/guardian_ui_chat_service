import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/custom_bottom_nav_bar.dart';
import 'package:myapp/widgets/child/buy_additional_time_dialog.dart';
import 'package:myapp/data/user_data.dart';
import 'package:myapp/services/app_usage_service.dart';
import 'package:myapp/services/app_icon_cache.dart';
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
  final _appUsageService = AppUsageService();
  final _appIconCache = AppIconCache();

  List<AppUsageInfo> _todayUsage = [];
  Duration _totalScreenTime = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _appIconCache.preloadApps();
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    final hasPermission = await _appUsageService.hasUsageStatsPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final usage = await _appUsageService.getTodayUsage();
    final totalMs = usage.fold<int>(
      0,
      (sum, app) => sum + app.totalTimeInForeground.inMilliseconds,
    );

    if (mounted) {
      setState(() {
        _todayUsage = usage;
        _totalScreenTime = Duration(milliseconds: totalMs);
        _loading = false;
      });
    }
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
                Text(
                  'App Usage and Limitations',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
    const limitHours = 4.0;
    final usedHours = _totalScreenTime.inMinutes / 60.0;
    final percent = (usedHours / limitHours).clamp(0.0, 1.0);
    final screenTimeText = _formatDuration(_totalScreenTime);

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
                    UserData.points.toString(),
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
    if (_loading) {
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

    if (_todayUsage.isEmpty) {
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
            'No app usage data yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textGrey,
            ),
          ),
        ),
      );
    }

    final appsToShow = _todayUsage.take(10).toList();

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
          for (int i = 0; i < appsToShow.length; i++) ...[
            _buildRealAppUsageItem(app: appsToShow[i]),
            if (i < appsToShow.length - 1) _buildDivider(),
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

    const allowedHours = 5;
    final usedHours = app.totalTimeInForeground.inMinutes / 60.0;
    final timeString = '${usedHours.toInt()}hr / ${allowedHours}hr';

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
