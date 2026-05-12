import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/screens/child/home_screen.dart';
import 'package:myapp/screens/child/ai_setup_screen.dart';
import 'package:myapp/screens/child/tasks_screen.dart';
import 'package:myapp/screens/child/chat_screen.dart';
import 'package:myapp/screens/child/safety_screen.dart';
import 'package:myapp/screens/child/child_profile_screen.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/child/ai_inference.dart';
import 'package:myapp/services/child/usage_submission_service.dart';
import 'package:myapp/services/child/app_blocker_service.dart';
import 'package:myapp/services/child/installed_apps_sync_service.dart';
import 'package:myapp/services/session_service.dart';
import 'package:myapp/services/child/feedback_loop_controller.dart';
import 'package:myapp/widgets/child/sos_bottom_sheet.dart';
import 'package:myapp/widgets/child/custom_bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  final VoidCallback? onReady;

  const MainLayout({super.key, this.onReady});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _dbReady = false;
  bool _aiPrompted = false;
  final FeedbackLoopController _feedbackLoop = FeedbackLoopController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDb();
  }

  @override
  void dispose() {
    _feedbackLoop.stop();
    _feedbackLoop.dispose();
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
    await _syncChildProfileFromCloud();
    _syncAppLimitsFromCloud();

    final modelReady = await AiChannel.ensureModel();
    if (modelReady) {
      _feedbackLoop.start();
    } else {
      _scheduleAiSetupPrompt();
    }
    if (mounted) {
      setState(() => _dbReady = true);
      widget.onReady?.call();
    }
  }

  void _scheduleAiSetupPrompt() {
    if (_aiPrompted) return;
    _aiPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.scaffoldBackground,
            title: const Text('AI model not ready'),
            content: const Text(
              'Guardian AI needs a local model to analyze screenshots. You can set it up now or continue without AI alerts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiModelSetupScreen(),
                    ),
                  );
                },
                child: const Text('Set up AI model'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _syncChildProfileFromCloud() async {
    try {
      final session = await SessionService.getChildSession();
      final deviceToken = session['deviceToken'];
      final childHash = session['childHash'];

      if (deviceToken == null || childHash == null) {
        debugPrint('Child profile sync skipped: missing credentials');
        return;
      }

      final result = await AuthService().getChildProfile(
        childHash: childHash,
        deviceToken: deviceToken,
      );

      if (result['success'] == true && result['data'] is Map) {
        await AppDatabase().child.upsertChildProfile(
          Map<String, dynamic>.from(result['data'] as Map),
        );
      }
    } catch (e) {
      debugPrint('Error syncing child profile: $e');
    }
  }

  Future<void> _syncAppLimitsFromCloud() async {
    try {
      final session = await SessionService.getChildSession();
      final deviceToken = session['deviceToken'];
      final childHash = session['childHash'];

      if (deviceToken == null || childHash == null) {
        print('App limits sync skipped: missing credentials');
        return;
      }

      final result = await AuthService().getChildAppLimits(
        childHash: childHash,
        deviceToken: deviceToken,
      );

      if (result['success'] == true && result['data'] is Map) {
        final data = result['data'] as Map<String, dynamic>;
        final limits = data['limits'] as List?;
        if (limits != null) {
          final limitsList = limits
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          await AppDatabase().child.saveAppLimits(limitsList);
          print('Synced ${limits.length} app limits to local DB');
          await AppBlockerService().syncNativeLimitsFromDatabase();
          await AppBlockerService().refreshEnforcementFromDatabase();
        }
      }
    } catch (e) {
      print('Error syncing app limits: $e');
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
