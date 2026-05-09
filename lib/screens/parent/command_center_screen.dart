import 'package:flutter/material.dart';
import 'package:myapp/screens/parent/blocked_apps_sites_screen.dart';
import 'package:myapp/screens/parent/set_app_timing_screen.dart';
import 'package:myapp/screens/parent/assign_task_screen.dart';
import 'package:myapp/widgets/parent/set_screen_time_bottom_sheet.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/parent/app_parent_database.dart';

class CommandCenterScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String email;
  final String password;
  final String childHash;

  const CommandCenterScreen({
    super.key,
    required this.onBack,
    required this.email,
    required this.password,
    required this.childHash,
  });

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  final AuthService _auth = AuthService();
  final AppParentDatabase _db = AppParentDatabase();
  bool isSleepModeOn = true;
  bool isExamModeOn = false;
  Duration screenTimeLimit = const Duration(hours: 3);

  @override
  void initState() {
    super.initState();
    _syncTasks();
  }

  Future<void> _syncTasks() async {
    final result = await _auth.getTasks(
      email: widget.email,
      password: widget.password,
      childHash: widget.childHash,
    );

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final cloudTasks = data?['tasks'] as List<dynamic>?;
      if (cloudTasks != null && cloudTasks.isNotEmpty) {
        // Get existing tasks to check for duplicates
        final existingTasks = await _db.getTasks(childHash: widget.childHash);
        
        for (final task in cloudTasks) {
          if (task is Map) {
            final incomingId = task['id'];
            int? incomingIdInt;
            if (incomingId is int) {
              incomingIdInt = incomingId;
            } else if (incomingId is String) {
              incomingIdInt = int.tryParse(incomingId);
            }
            
            // Check if this task already exists in local DB by remote_id
            bool exists = false;
            for (final existing in existingTasks) {
              final existingId = existing['remote_id'];
              int? existingIdInt;
              if (existingId is int) {
                existingIdInt = existingId;
              } else if (existingId is String) {
                existingIdInt = int.tryParse(existingId);
              }
              if (incomingIdInt != null && incomingIdInt == existingIdInt) {
                exists = true;
                break;
              }
            }
            
            if (exists) continue;
            
            // Cloud returns duration in minutes, convert to seconds for local DB
            final durationSeconds = (task['duration'] as int? ?? 0) * 60;
            
            await _db.upsertTask(
              childHash: widget.childHash,
              name: task['name'] ?? '',
              category: task['category'] ?? 'Chore',
              duration: durationSeconds,
              remoteId: incomingIdInt,
              state: task['state'] ?? 'pending',
              rewardPoints: task['reward_points'] ?? 3,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Command Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                const SizedBox(height: 12),
                
                const Text(
                  'Screen Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Screen Time Card
                _buildActionCard(
                  title: 'Screen Time',
                  subtitlePrefix: 'Daily Limit : ',
                  subtitleHighlight: '${screenTimeLimit.inHours} hr ${screenTimeLimit.inMinutes % 60} mins',
                  gradient: const [AppColors.primaryGradientEnd, AppColors.primaryGradientStart],
                  trailing: _buildIconBtn(Icons.edit, onTap: () async {
                    final newDuration = await showModalBottomSheet<Duration>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => SetScreenTimeBottomSheet(
                        initialDuration: screenTimeLimit,
                      ),
                    );

                    if (newDuration != null) {
                      setState(() {
                        screenTimeLimit = newDuration;
                      });
                    }
                  }),
                ),
                const SizedBox(height: 16),
                
                // App Timing Card
                _buildActionCard(
                  title: 'App Timing',
                  subtitlePrefix: 'Set Time Limit For Apps',
                  gradient: const [AppColors.primaryGradientEnd, AppColors.primaryGradientStart],
                  trailing: _buildIconBtn(Icons.edit, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SetAppTimingScreen(
                          email: widget.email,
                          password: widget.password,
                          childHash: widget.childHash,
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 32),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Sleep Mode
                _buildActionCard(
                  title: 'Sleep Mode',
                  gradient: const [AppColors.tertiaryGradientStart, AppColors.tertiaryGradientEnd],
                  trailing: _buildToggleSwitch(
                    value: isSleepModeOn,
                    onChanged: (val) {
                      setState(() {
                        isSleepModeOn = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Exam Mode
                _buildActionCard(
                  title: 'Exam Mode',
                  gradient: const [AppColors.tertiaryGradientStart, AppColors.tertiaryGradientEnd],
                  trailing: _buildToggleSwitch(
                    value: isExamModeOn,
                    onChanged: (val) {
                      setState(() {
                        isExamModeOn = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Block Apps & Sites
                _buildActionCard(
                  title: 'Block Apps & Sites',
                  subtitlePrefix: 'Block Specific Apps & Sites\nFrom your child',
                  gradient: const [AppColors.tertiaryGradientStart, AppColors.tertiaryGradientEnd],
                  trailing: _buildIconBtn(Icons.arrow_forward_ios, size: 14, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BlockedAppsSitesScreen()),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Tasks
                _buildActionCard(
                  title: 'Tasks',
                  subtitlePrefix: 'View and Assign tasks to child',
                  gradient: const [AppColors.tertiaryGradientStart, AppColors.tertiaryGradientEnd],
                  trailing: _buildIconBtn(Icons.arrow_forward_ios, size: 14, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AssignTaskScreen()),
                    );
                  }),
                ),
                
                const SizedBox(height: 100), // Padding for bottom nav
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    String? subtitlePrefix,
    String? subtitleHighlight,
    required List<Color> gradient,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitlePrefix != null) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: subtitlePrefix,
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                        if (subtitleHighlight != null)
                          TextSpan(
                            text: subtitleHighlight,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {required VoidCallback onTap, double size = 18}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.cmdIconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF2B2B2B), size: size),
      ),
    );
  }

  Widget _buildToggleSwitch({required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF00B65D) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
              left: value ? 24 : 2,
              top: 2,
              right: value ? 2 : 24,
              bottom: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
