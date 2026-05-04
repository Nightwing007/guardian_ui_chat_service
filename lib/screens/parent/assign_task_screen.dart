import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/add_task_bottom_sheet.dart';

enum TaskStatus {
  completed, // green
  notAccepted, // red
  ongoing, // gray
}

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  // Mock data for 3 default tasks
  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Do Home Work',
      'duration': '5m',
      'status': TaskStatus.completed,
    },
    {
      'title': 'Read Book',
      'duration': '15m',
      'status': TaskStatus.notAccepted,
    },
    {
      'title': 'Listen a Podcast',
      'duration': '1h',
      'status': TaskStatus.ongoing,
    },
  ];

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return const Color(0xFF00B65D); // Green
      case TaskStatus.notAccepted:
        return const Color(0xFFE80026); // Red
      case TaskStatus.ongoing:
        return Colors.grey.shade500; // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Assign Task',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await showModalBottomSheet<Map<String, String>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: const AddTaskBottomSheet(),
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          _tasks.add({
                            'title': result['title'],
                            'duration': result['duration'],
                            'status': TaskStatus.notAccepted,
                          });
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Tasks List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final statusColor = _getStatusColor(task['status'] as TaskStatus);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222), // Lighter dark grey
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        // Status Circle Outline
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Task Info
                        Expanded(
                          child: Text(
                            task['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Duration
                        Text(
                          task['duration'] as String,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Edit Icon
                        GestureDetector(
                          onTap: () async {
                            // Parse duration
                            final durationStr = task['duration'] as String;
                            int hours = 0;
                            int minutes = 0;
                            
                            if (durationStr.contains('h')) {
                              final parts = durationStr.split('h');
                              hours = int.tryParse(parts[0]) ?? 0;
                              if (parts.length > 1 && parts[1].contains('m')) {
                                minutes = int.tryParse(parts[1].replaceAll('m', '').trim()) ?? 0;
                              }
                            } else if (durationStr.contains('m')) {
                              minutes = int.tryParse(durationStr.replaceAll('m', '').trim()) ?? 0;
                            }

                            final result = await showModalBottomSheet<Map<String, String>>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: AddTaskBottomSheet(
                                  initialName: task['title'] as String,
                                  initialDuration: Duration(hours: hours, minutes: minutes),
                                ),
                              ),
                            );

                            if (result != null) {
                              setState(() {
                                _tasks[index]['title'] = result['title'];
                                _tasks[index]['duration'] = result['duration'];
                              });
                            }
                          },
                          child: Icon(Icons.edit_outlined, color: Colors.grey.shade400, size: 20),
                        ),
                        const SizedBox(width: 16),
                        
                        // Delete Icon
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _tasks.removeAt(index);
                            });
                          },
                          child: const Icon(Icons.delete_outline, color: Color(0xFFE80026), size: 20),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
