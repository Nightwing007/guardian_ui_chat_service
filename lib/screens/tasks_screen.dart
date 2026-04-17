import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/task_widget.dart';
import 'package:myapp/data/user_data.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _completedTasks = 0;
  final int _totalTasks = 5;

  void _incrementCompletedTasks() {
    setState(() {
      if (_completedTasks < _totalTasks) {
        _completedTasks++;
        UserData.points += 3;
      }
    });
  }

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
          TaskWidget(
            taskName: 'MORNING READING',
            taskCategory: 'Daily Task',
            timerTime: '5m',
            gradientColors: AppColors.allTaskGradients[0],
            onCompleted: _incrementCompletedTasks,
          ),
          TaskWidget(
            taskName: 'CLEAN ROOM',
            taskCategory: 'Chores',
            timerTime: '15m',
            gradientColors: AppColors.allTaskGradients[1],
            onCompleted: _incrementCompletedTasks,
          ),
          TaskWidget(
            taskName: 'HOMEWORK',
            taskCategory: 'Study',
            timerTime: '45m',
            gradientColors: AppColors.allTaskGradients[2],
            onCompleted: _incrementCompletedTasks,
          ),
          TaskWidget(
            taskName: 'EXERCISE',
            taskCategory: 'Daily Task',
            timerTime: '20m',
            gradientColors: AppColors.allTaskGradients[3],
            onCompleted: _incrementCompletedTasks,
          ),
          TaskWidget(
            taskName: 'WATER PLANTS',
            taskCategory: 'Chores',
            timerTime: '10m',
            gradientColors: AppColors.allTaskGradients[4],
            onCompleted: _incrementCompletedTasks,
          ),
          const SizedBox(height: 120), // Padding to clear the bottom floating nav bar
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
                      '${UserData.points} pts',
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
                width: 200, // Constrain width so text wraps and doesn't overlap image
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
                width: 200, // Match width constrain
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
                        color: Colors.white, // White thumb
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
               width: 140, // Increased width for the new illustration
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
