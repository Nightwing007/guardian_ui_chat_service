import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/screen_time_screen.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/child/app_icon_cache.dart';
import 'package:myapp/services/child/app_usage_service.dart';
import 'package:myapp/services/child/installed_apps_sync_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _db = AppDatabase();
  final _appIconCache = AppIconCache();
  int _allowedScreenTimeMinutes = 240;
  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUsage();
    _appIconCache.preloadApps();
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUsage();
    }
  }

  Future<void> _refreshUsage() async {
    await _db.child.refreshUsageData();
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final allowed = await _db.child.getTotalAllowedScreenTimeMinutes();
    if (mounted) setState(() => _allowedScreenTimeMinutes = allowed);
  }

  Future<void> _syncCloudDb() async {
    if (_isSyncingCloud) return;

    setState(() => _isSyncingCloud = true);
    try {
      final synced = await InstalledAppsSyncService()
          .syncLocalInstalledAppsToCloud();
      await _refreshUsage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Cloud sync completed'
                : 'Nothing synced. Check pairing and local app data.',
          ),
          backgroundColor: synced ? null : Colors.orangeAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud sync failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingCloud = false);
    }
  }

  /// Formats a Duration into a readable string like "2h 15m" or "45m".
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '<1m';
  }

  /// Returns the appropriate screen usage image based on usage percentage.
  String _getScreenUsageImage(double percent) {
    if (percent >= 0.8) {
      return 'assets/images/screenusage/high.png';
    } else if (percent >= 0.4) {
      return 'assets/images/screenusage/medium.png';
    } else {
      return 'assets/images/screenusage/Default.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          _buildMotivationalCard(),
          const SizedBox(height: 20),
          _buildScreenTimeCard(context),
          const SizedBox(height: 30),
          Text(
            'Apps Used Today',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          _buildAppsList(),
          const SizedBox(
            height: 120,
          ), // Extra padding to scroll past the floating navbar
        ],
      ),
    );
  }

  /// Builds the top header containing the user's profile picture,
  /// a greeting, and a motivational subtitle.
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?img=11',
              ), // Placeholder for boy avatar
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hi Alex ',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                Text(
                  "You're doing great today!",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
        Tooltip(
          message: 'Sync cloud',
          child: IconButton(
            onPressed: _isSyncingCloud ? null : _syncCloudDb,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E2D4A),
              disabledBackgroundColor: const Color(0xFF1E2D4A),
              foregroundColor: Colors.white,
              disabledForegroundColor: AppColors.textGrey,
            ),
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentBlue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  /// Builds the motivational quote card showing a gradient background
  /// and the robot assistant avatar.
  Widget _buildMotivationalCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.secondaryGradientStart,
                  AppColors.secondaryGradientEnd,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "Do the best you can until you\nknow better. Then when you know\nbetter, do better",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Image.asset('assets/images/robohead.png', height: 60, width: 60),
      ],
    );
  }

  /// Builds the main screen time reporting card with real data.
  Widget _buildScreenTimeCard(BuildContext context) {
    final child = _db.child;
    final screenTimeText = _formatDuration(child.totalUsedScreenTime);
    final limitHours = _allowedScreenTimeMinutes / 60.0;
    final usedHours = child.totalUsedScreenTime.inMinutes / 60.0;
    final percent = (usedHours / limitHours).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScreenTimeScreen(
              currentNavIndex: 0,
              onNavTap: (index) {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(index);
                }
              },
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.tertiaryGradientStart,
              AppColors.tertiaryGradientEnd,
            ],
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircularPercentIndicator(
                  radius: 70.0,
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
                    ],
                  ),
                  progressColor: percent >= 1.0
                      ? Colors.redAccent
                      : AppColors.accentBlue,
                  backgroundColor: const Color(0xFF1E2D4A),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                Image.asset(
                  _getScreenUsageImage(percent),
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the list of apps used today with real usage data.
  Widget _buildAppsList() {
    final child = _db.child;

    if (child.isUsageLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientEnd,
            ],
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

    if (child.appUsageList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.apps, color: AppColors.textGrey, size: 40),
              const SizedBox(height: 12),
              Text(
                'No app usage data yet',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Grant Usage Access permission to see your apps',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Take up to 10 most-used apps
    final appsToShow = child.appUsageList.take(10).toList();
    final maxDuration = appsToShow.first.totalTimeInForeground;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          for (int i = 0; i < appsToShow.length; i++) ...[
            _buildRealAppUsageItem(
              app: appsToShow[i],
              maxDuration: maxDuration,
            ),
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

  /// Builds a single app usage row with real data.
  Widget _buildRealAppUsageItem({
    required AppUsageInfo app,
    required Duration maxDuration,
  }) {
    final percent = maxDuration.inMilliseconds > 0
        ? (app.totalTimeInForeground.inMilliseconds /
                  maxDuration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    final timeText = _formatDuration(app.totalTimeInForeground);
    String displayName = app.appName;
    if (displayName.contains('.')) {
      displayName = displayName.split('.').last;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _appIconCache.getAppIconWidget(app.packageName),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  lineHeight: 6.0,
                  percent: percent,
                  backgroundColor: Colors.grey.shade700,
                  progressColor: AppColors.accentBlue,
                  barRadius: const Radius.circular(5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
