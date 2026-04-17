import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/screen_time_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

  /// Builds the main screen time reporting card. This includes a circular
  /// progress indicator comparing current usage to the daily limit, and an illustration.
  Widget _buildScreenTimeCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScreenTimeScreen(
              currentNavIndex: 0,
              onNavTap: (index) {},
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
                percent: 2.25 / 4.0, // 2h 15m out of 4h
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "2h 15m",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "OF 4H LIMIT",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                progressColor: AppColors.accentBlue,
                backgroundColor: const Color(0xFF1E2D4A), // Darker blue background
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

  /// Builds the list of apps used today. Displays each app's icon, name,
  /// time spent, and a visual linear progress bar.
  Widget _buildAppsList() {
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
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.youtube, color: Colors.red, size: 24),
            appName: 'YouTube',
            timeString: '5hr / 6hr',
            percent: 5 / 6,
            progressColor: AppColors.accentBlue,
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 24),
            appName: 'WhatsApp',
            timeString: '3hr / 5hr',
            percent: 3 / 5,
            progressColor: AppColors.accentBlue,
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.instagram, color: Colors.purpleAccent, size: 24),
            appName: 'Instagram',
            timeString: '1hr / 5hr',
            percent: 1 / 5,
            progressColor: AppColors.accentBlue,
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.chrome, color: Colors.red, size: 24),
            appName: 'Chrome',
            timeString: '4hr / 4hr',
            percent: 1.0,
            progressColor: Colors.redAccent,
          ),
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

  Widget _buildAppUsageItem({
    required Widget iconView,
    required String appName,
    required String timeString,
    required double percent,
    required Color progressColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: iconView,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appName,
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
                  progressColor: progressColor,
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
