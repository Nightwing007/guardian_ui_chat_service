import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/child/home_screen.dart';
import 'package:myapp/screens/child/tasks_screen.dart';
import 'package:myapp/screens/child/chat_screen.dart';
import 'package:myapp/screens/child/safety_screen.dart';
import 'package:myapp/screens/child/child_profile_screen.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/custom_bottom_nav_bar.dart';
import 'package:myapp/widgets/child/sos_bottom_sheet.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/child/usage_submission_service.dart';
import 'package:myapp/services/child/app_blocker_service.dart';
import 'package:myapp/services/child/installed_apps_sync_service.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback? onReady;

  const MainLayout({super.key, this.onReady});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _dbReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDb();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UsageSubmissionService().stop();
    AppBlockerService().stopMonitoring();
    InstalledAppsSyncService().stopPackageChangeWatcher();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UsageSubmissionService().start();
      AppBlockerService().startMonitoring();
    } else if (state == AppLifecycleState.paused) {
      UsageSubmissionService().stop();
    }
  }

  Future<void> _initDb() async {
    await AppDatabase().initialize();
    await AppBlockerService().startMonitoring();
    InstalledAppsSyncService().syncInstalledApps();
    InstalledAppsSyncService().startPackageChangeWatcher();
    if (mounted) {
      setState(() => _dbReady = true);
      widget.onReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_dbReady) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

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
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                onNavigate: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              const TasksScreen(),
              const ChatScreen(),
              const SafetyScreen(),
              const ChildProfileScreen(),
            ],
          ),
        ),
        floatingActionButton: _currentIndex == 0
            ? Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: FloatingActionButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SosBottomSheet(
                        onChatPressed: () {
                          setState(() {
                            _currentIndex = 2; // Jump to Chat tab
                          });
                        },
                      ),
                    );
                  },
                  backgroundColor: AppColors.sosRed,
                  shape: const CircleBorder(),
                  child: Text(
                    'SOS',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
