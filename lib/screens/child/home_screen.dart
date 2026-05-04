import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/screen_time_screen.dart';
import 'package:myapp/services/app_usage_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _appUsageService = AppUsageService();

  List<AppUsageInfo> _todayUsage = [];
  Duration _totalScreenTime = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsageData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUsageData();
    }
  }

  Future<void> _loadUsageData() async {
    final hasPermission = await _appUsageService.hasUsageStatsPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _todayUsage = [];
          _totalScreenTime = Duration.zero;
          _loading = false;
        });
      }
      return;
    }

    final usage = await _appUsageService.getTodayUsage();

    // Compute total screen time from all apps
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

  /// Formats a Duration into a readable string like "2h 15m" or "45m".
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
          const SizedBox(height: 120), // Extra padding to scroll past the floating navbar
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
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Placeholder for boy avatar
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
                colors: [AppColors.secondaryGradientStart, AppColors.secondaryGradientEnd],
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
        Image.asset(
          'assets/images/robohead.png',
          height: 60,
          width: 60,
        ),
      ],
    );
  }

  /// Builds the main screen time reporting card with real data.
  Widget _buildScreenTimeCard(BuildContext context) {
    final screenTimeText = _formatDuration(_totalScreenTime);
    // Use 4h as a reasonable daily limit for display
    const limitHours = 4.0;
    final usedHours = _totalScreenTime.inMinutes / 60.0;
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
                progressColor: percent >= 1.0 ? Colors.redAccent : AppColors.accentBlue,
                backgroundColor: const Color(0xFF1E2D4A),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              Image.asset(
                'assets/images/screenusage/Default.png',
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
    final appsToShow = _todayUsage.take(10).toList();
    final maxDuration = appsToShow.first.totalTimeInForeground;

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

    // Generate a consistent color from the package name
    final colorIndex = app.packageName.hashCode.abs() % _appColors.length;
    final appColor = _appColors[colorIndex];

    // Get the first letter of the app name for the icon
    final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?';

    // Try to get a known icon for common apps
    final iconWidget = _getAppIcon(app.packageName, app.appName) ??
        Text(
          initial,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: appColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: iconWidget),
          ),
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
                        app.appName,
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

  /// Returns a FontAwesome icon for well-known apps, or null.
  Widget? _getAppIcon(String packageName, String appName) {
    final pkg = packageName.toLowerCase();
    final name = appName.toLowerCase();

    if (pkg.contains('youtube') || name.contains('youtube')) {
      return const FaIcon(FontAwesomeIcons.youtube, color: Colors.white, size: 20);
    }
    if (pkg.contains('whatsapp') || name.contains('whatsapp')) {
      return const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20);
    }
    if (pkg.contains('instagram') || name.contains('instagram')) {
      return const FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: 20);
    }
    if (pkg.contains('chrome') || name.contains('chrome')) {
      return const FaIcon(FontAwesomeIcons.chrome, color: Colors.white, size: 20);
    }
    if (pkg.contains('facebook') || name.contains('facebook')) {
      return const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 20);
    }
    if (pkg.contains('twitter') || pkg.contains('x.com') || name == 'x') {
      return const FaIcon(FontAwesomeIcons.xTwitter, color: Colors.white, size: 20);
    }
    if (pkg.contains('snapchat') || name.contains('snapchat')) {
      return const FaIcon(FontAwesomeIcons.snapchat, color: Colors.white, size: 20);
    }
    if (pkg.contains('telegram') || name.contains('telegram')) {
      return const FaIcon(FontAwesomeIcons.telegram, color: Colors.white, size: 20);
    }
    if (pkg.contains('spotify') || name.contains('spotify')) {
      return const FaIcon(FontAwesomeIcons.spotify, color: Colors.white, size: 20);
    }
    if (pkg.contains('tiktok') || name.contains('tiktok')) {
      return const FaIcon(FontAwesomeIcons.tiktok, color: Colors.white, size: 20);
    }
    if (pkg.contains('discord') || name.contains('discord')) {
      return const FaIcon(FontAwesomeIcons.discord, color: Colors.white, size: 20);
    }
    if (pkg.contains('reddit') || name.contains('reddit')) {
      return const FaIcon(FontAwesomeIcons.reddit, color: Colors.white, size: 20);
    }
    if (pkg.contains('pinterest') || name.contains('pinterest')) {
      return const FaIcon(FontAwesomeIcons.pinterest, color: Colors.white, size: 20);
    }
    if (pkg.contains('linkedin') || name.contains('linkedin')) {
      return const FaIcon(FontAwesomeIcons.linkedin, color: Colors.white, size: 20);
    }
    if (pkg.contains('github') || name.contains('github')) {
      return const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 20);
    }
    if (pkg.contains('google.android.gm') || name.contains('gmail')) {
      return const FaIcon(FontAwesomeIcons.envelope, color: Colors.white, size: 20);
    }
    if (pkg.contains('android.dialer') || name.contains('phone')) {
      return const Icon(Icons.phone, color: Colors.white, size: 20);
    }
    if (pkg.contains('android.apps.messaging') || name.contains('messages')) {
      return const Icon(Icons.message, color: Colors.white, size: 20);
    }
    if (pkg.contains('camera') || name.contains('camera')) {
      return const Icon(Icons.camera_alt, color: Colors.white, size: 20);
    }
    if (pkg.contains('gallery') || pkg.contains('photos') || name.contains('photos')) {
      return const Icon(Icons.photo_library, color: Colors.white, size: 20);
    }
    if (pkg.contains('settings') || name.contains('settings')) {
      return const Icon(Icons.settings, color: Colors.white, size: 20);
    }
    if (pkg.contains('clock') || name.contains('clock')) {
      return const Icon(Icons.access_time, color: Colors.white, size: 20);
    }
    if (pkg.contains('calendar') || name.contains('calendar')) {
      return const Icon(Icons.calendar_today, color: Colors.white, size: 20);
    }
    if (pkg.contains('maps') || name.contains('maps')) {
      return const Icon(Icons.map, color: Colors.white, size: 20);
    }

    return null;
  }

  // Color palette for app icon backgrounds
  static const _appColors = [
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFFB8C00), // orange
    Color(0xFF00ACC1), // cyan
    Color(0xFF3949AB), // indigo
    Color(0xFFD81B60), // pink
    Color(0xFF5E35B1), // deep purple
    Color(0xFF039BE5), // light blue
    Color(0xFF7CB342), // light green
    Color(0xFFFF6F00), // amber
  ];
}
