import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/task_widget.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/models/child/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _db = AppDatabase();
  final _auth = AuthService();
  List<Map<String, dynamic>> _tasks = [];
  int _totalPoints = 10;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final mapTasks = await _db.child.getTasks();
    final taskModels = await _db.child.getTaskModels();
    final points = await _db.child.getTotalPoints();

    if (mounted) {
      setState(() {
        if (mapTasks.isNotEmpty) {
          _tasks = mapTasks;
        } else {
          _tasks = taskModels
              .map(
                (t) => {
                  'id': t.id,
                  'name': t.name,
                  'category': t.category,
                  'duration': _parseDurationToSeconds(t.timerTime),
                  'state': t.state.name,
                },
              )
              .toList();
        }
        _totalPoints = points;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFromCloud() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final settings = await _db.child.getLinkedChildSettings();
      final deviceToken = settings['deviceToken'];
      final childHash = settings['childHash'];

      if (deviceToken != null && childHash != null) {
        final result = await _auth.getChildTasks(
          childHash: childHash,
          deviceToken: deviceToken,
        );
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>?;
          final tasks = data?['tasks'] as List<dynamic>?;
          if (tasks != null) {
            await _db.child.syncCloudTasks(tasks.cast<Map<String, dynamic>>());
          }
        }
      }
    } catch (e) {
      print('_refreshFromCloud error: $e');
    }

    await _loadData();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  int _parseDurationToSeconds(String timerTime) {
    if (timerTime.contains('h')) {
      final parts = timerTime.split('h');
      final hours = int.tryParse(parts[0]) ?? 0;
      final mins = parts.length > 1
          ? (int.tryParse(parts[1].replaceAll('m', '')) ?? 0)
          : 0;
      return (hours * 60 + mins) * 60;
    } else if (timerTime.contains('m')) {
      final mins = int.tryParse(timerTime.replaceAll('m', '')) ?? 0;
      return mins * 60;
    }
    return 0;
  }

  Future<void> _onTaskCompleted(int taskId) async {
    await _db.child.updateTaskState(taskId, TaskState.completed);
    await _db.child.addPoints(3);
    await _updateRemoteTaskState(taskId, 'completed');
    await _loadData();
  }

  Future<void> _onTaskAccepted(int taskId) async {
    await _db.child.updateTaskState(taskId, TaskState.inProgress);
    await _updateRemoteTaskState(taskId, 'in_progress');
  }

  Future<void> _updateRemoteTaskState(int localTaskId, String state) async {
    final task = _tasks.cast<Map<String, dynamic>?>().firstWhere(
      (task) => task?['id'] == localTaskId,
      orElse: () => null,
    );
    final remoteTaskId = task?['remote_id'] as int?;
    if (remoteTaskId == null) return;

    try {
      final settings = await _db.child.getLinkedChildSettings();
      final deviceToken = settings['deviceToken'];
      final childHash = settings['childHash'];
      if (deviceToken == null || childHash == null) return;

      final result = await _auth.updateChildTaskState(
        childHash: childHash,
        deviceToken: deviceToken,
        taskId: remoteTaskId,
        state: state,
      );
      if (result['success'] != true) {
        debugPrint('Failed to update remote task state: ${result['message']}');
      }
    } catch (e) {
      debugPrint('Remote task state update error: $e');
    }
  }

  int get _completedTasks =>
      _tasks.where((t) => t['state'] == 'completed').length;
  int get _totalTasks => _tasks.length;

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      return '${hours}h${mins > 0 ? '${mins}m' : ''}';
    }
    return '${seconds ~/ 60}m';
  }

  TaskState _parseTaskState(String state) {
    switch (state) {
      case 'accepted':
        return TaskState.accepted;
      case 'in_progress':
      case 'inProgress':
        return TaskState.inProgress;
      case 'completed':
        return TaskState.completed;
      default:
        return TaskState.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        Text(
          'Your Tasks',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete your Todays Tasks',
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textGrey),
        ),
        const SizedBox(height: 24),
        _buildSummaryCard(),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          ...List.generate(_tasks.length, (index) {
            final task = _tasks[index];
            return TaskWidget(
              taskId: task['id'] as int,
              taskName: task['name'] as String,
              taskCategory: task['category'] as String,
              timerTime: _formatDuration(task['duration'] as int),
              gradientColors: AppColors
                  .allTaskGradients[index % AppColors.allTaskGradients.length],
              onAccepted: _onTaskAccepted,
              onCompleted: _onTaskCompleted,
              initialState: _parseTaskState(task['state'] as String),
            );
          }),
        const SizedBox(height: 120),
      ],
    );

    return RefreshIndicator(
      onRefresh: _refreshFromCloud,
      color: Colors.white,
      backgroundColor: AppColors.primaryGradientStart,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: content,
      ),
    );
  }

  Widget _buildSummaryCard() {
    double progress = _totalTasks == 0 ? 0 : _completedTasks / _totalTasks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Tasks Completed\nToday: $_completedTasks/$_totalTasks',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$_totalPoints pts',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: Text(
                  'Complete tasks to unlock\nyour screen time',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textGrey,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY GOAL',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 140,
              child: Image.asset(
                'assets/images/task-summary-ill.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
