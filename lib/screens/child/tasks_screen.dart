import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/child/task_widget.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/models/child/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _db = AppDatabase();
  List<TaskModel> _tasks = [];
  int _totalPoints = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tasks = await _db.child.getTasks();
    final points = await _db.child.getTotalPoints();
    if (mounted) setState(() {
      _tasks = tasks;
      _totalPoints = points;
      _isLoading = false;
    });
  }

  Future<void> _onTaskCompleted(int taskId) async {
    await _db.child.updateTaskState(taskId, TaskState.completed);
    await _db.child.addPoints(3);
    await _loadData();
  }

  int get _completedTasks => _tasks.where((t) => t.state == TaskState.completed).length;
  int get _totalTasks => _tasks.length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            ...List.generate(_tasks.length, (index) {
              return TaskWidget(
                taskId: _tasks[index].id,
                taskName: _tasks[index].name,
                taskCategory: _tasks[index].category,
                timerTime: _tasks[index].timerTime,
                gradientColors: AppColors.allTaskGradients[index % AppColors.allTaskGradients.length],
                onCompleted: _onTaskCompleted,
                initialState: _tasks[index].state,
              );
            }),
          const SizedBox(height: 120),
        ],
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
          colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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