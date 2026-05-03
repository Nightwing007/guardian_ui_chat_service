import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/custom_bottom_nav_bar.dart';
import 'package:myapp/widgets/child/buy_additional_time_dialog.dart';
import 'package:myapp/data/user_data.dart';
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
                progressColor: AppColors.accentBlue,
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
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 24),
            appName: 'WhatsApp',
            timeString: '3hr / 5hr',
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.instagram, color: Colors.purpleAccent, size: 24),
            appName: 'Instagram',
            timeString: '1hr / 5hr',
          ),
          _buildDivider(),
          _buildAppUsageItem(
            iconView: const FaIcon(FontAwesomeIcons.chrome, color: Colors.red, size: 24),
            appName: 'Chrome',
            timeString: '2hr / 5hr',
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.sosRed, // Red icon background specifically asked for in ref
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              child: iconView,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Row(
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
                builder: (context) => BuyAdditionalTimeDialog(appName: appName),
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
