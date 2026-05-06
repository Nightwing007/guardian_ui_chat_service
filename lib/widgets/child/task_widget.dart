import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/models/child/task_model.dart';

class TaskWidget extends StatefulWidget {
  final int taskId;
  final String taskName;
  final String taskCategory;
  final String timerTime;
  final List<Color> gradientColors;
  final Function(int taskId)? onCompleted;
  final TaskState initialState;

  const TaskWidget({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.taskCategory,
    required this.timerTime,
    required this.gradientColors,
    this.onCompleted,
    this.initialState = TaskState.initial,
  });

  static Duration parseTimerTime(String timerTime) {
    final regex = RegExp(r'(\d+)([smh])');
    final match = regex.firstMatch(timerTime);
    if (match == null) return const Duration(seconds: 5);
    
    final value = int.parse(match.group(1)!);
    final unit = match.group(2);
    
    switch (unit) {
      case 's':
        return Duration(seconds: value);
      case 'm':
        return Duration(minutes: value);
      case 'h':
        return Duration(hours: value);
      default:
        return const Duration(seconds: 5);
    }
  }

  @override
  State<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> with SingleTickerProviderStateMixin {
  late TaskState _currentState;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    _animationController = AnimationController(
      vsync: this,
      duration: TaskWidget.parseTimerTime(widget.timerTime),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentState = TaskState.completed;
        });
        if (widget.onCompleted != null) {
          widget.onCompleted!(widget.taskId);
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (_currentState == TaskState.initial) {
      setState(() {
        _currentState = TaskState.accepted;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      // Clip to ensure the bottom animated bar matches the corner radius
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildLeadingIcon(),
                const SizedBox(width: 16),
                Expanded(child: _buildTextContent()),
                _buildActionButton(),
              ],
            ),
          ),
          if (_currentState == TaskState.accepted)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    height: 4,
                    color: Colors.white, // background track of the loader
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _animationController.value,
                      child: Container(
                        color: AppColors.sosRed, // The red loading progress
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        // When completed, add a subtle inner blue stroke/shadow visual as specified
        border: _currentState == TaskState.completed
            ? Border.all(color: const Color(0xFF4C61C3), width: 4)
            : null,
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.taskName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          widget.taskCategory,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    Color buttonColor;
    Color textColor = Colors.white;

    switch (_currentState) {
      case TaskState.initial:
        buttonText = 'ACCEPT';
        buttonColor = Colors.white.withValues(alpha: 0.2); // semi-transparent wrapper 
        break;
      case TaskState.accepted:
        buttonText = 'ACCEPTED';
        buttonColor = Colors.white.withValues(alpha: 0.2);
        break;
      case TaskState.completed:
        buttonText = 'COMPLETED';
        buttonColor = Colors.white.withValues(alpha: 0.1);
        textColor = Colors.white.withValues(alpha: 0.6); // slight fade for completion
        break;
    }

    return GestureDetector(
      onTap: _handleAccept,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          buttonText,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
