import 'package:flutter/material.dart';
import 'package:myapp/widgets/parent/parent_drawer.dart';
import 'package:myapp/widgets/parent/pending_request_card.dart';
import 'package:myapp/widgets/parent/screen_time_trends_card.dart';
import 'package:myapp/widgets/parent/app_usage_details_card.dart';
import 'package:myapp/widgets/parent/summary_screen_time_card.dart';
import 'package:myapp/widgets/parent/summary_top_apps_card.dart';
import 'package:myapp/widgets/parent/summary_risk_signals_card.dart';
import 'package:myapp/widgets/parent/summary_active_alerts_card.dart';

class ParentDashboardScreen extends StatelessWidget {
  final String email;
  final String password;
  final String childHash;
  final int localCacheVersion;

  const ParentDashboardScreen({
    super.key,
    required this.email,
    required this.password,
    required this.childHash,
    this.localCacheVersion = 0,
  });

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
        drawer: const ParentDrawer(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050505), // Very dark background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) {
                          return GestureDetector(
                            onTap: () {
                              Scaffold.of(context).openDrawer();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 2,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 18,
                                  height: 2,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 12,
                                  height: 2,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Stack(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            // If you have the image, use backgroundImage: AssetImage('assets/images/child_avatar.png')
                            child: Icon(Icons.person, color: Colors.grey),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF050505),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title and Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arav\'s Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A4A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Color(0xFF4285F4),
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 12,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C853),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Scrollable Summary Cards Carousel
                const _SummaryCarousel(),
                const SizedBox(height: 32),

                // Pending Requests
                const Text(
                  'Pending Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                PendingRequestCard(
                  childName: 'Arav',
                  timeAgo: '5 mins ago',
                  requestTitle: 'Want 30 mins on YouTube',
                  reason: 'Need to watch a homework video',
                  aiSuggestion:
                      'Approval Seems reasonable based on past behaviour and current time usage',
                  onApprove: () {},
                  onDecline: () {},
                ),
                const SizedBox(height: 32),

                // Weekly Activity
                const Text(
                  'Weekly Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const ScreenTimeTrendsCard(),
                const SizedBox(height: 32),

                // App Usage Details
                AppUsageDetailsCard(
                  key: ValueKey('app-usage-$childHash-$localCacheVersion'),
                  email: email,
                  password: password,
                  childHash: childHash,
                ),

                const SizedBox(height: 80), // Padding for bottom nav & FAB
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCarousel extends StatefulWidget {
  const _SummaryCarousel();

  @override
  State<_SummaryCarousel> createState() => _SummaryCarouselState();
}

class _SummaryCarouselState extends State<_SummaryCarousel> {
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
    initialPage: 1,
  );
  int _currentPage =
      1; // Default to second card (Risk Signals) as per screenshot

  final List<Widget> _cards = const [
    SummaryScreenTimeCard(),
    SummaryRiskSignalsCard(),
    SummaryTopAppsCard(),
    SummaryActiveAlertsCard(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _cards[index],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_cards.length, (index) {
            final isActive = _currentPage == index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 32 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
