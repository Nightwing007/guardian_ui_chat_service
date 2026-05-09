import 'package:flutter/material.dart';
import 'package:myapp/theme/app_colors.dart';
import 'package:myapp/widgets/parent/add_task_bottom_sheet.dart';
import 'package:myapp/services/parent/app_parent_database.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/session_service.dart';

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
  String? _childHash;
  String? _parentEmail;
  String? _parentPassword;
  final AppParentDatabase _db = AppParentDatabase();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionService.getParentSession();
    setState(() {
      _childHash = session['childHash'];
      _parentEmail = session['email'];
      _parentPassword = session['password'];
    });
    if (_childHash != null) {
      await _loadTasks();
    }
  }

Future<void> _loadTasks() async {
    if (_childHash == null) return;
    final tasks = await _db.getTasks(childHash: _childHash!);
    setState(() {
      _tasks.clear();
      _tasks.addAll(tasks.map((t) => {
        'title': t['name'],
        'duration': _formatDuration(t['duration'] as int),
        'status': _mapState(t['state'] as String),
        'localId': t['id'],
        'remote_id': t['remote_id'],
      }));
    });
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      return '${seconds ~/ 3600}h${seconds % 3600 > 0 ? '${(seconds % 3600) ~/ 60}m' : ''}';
    }
    return '${seconds ~/ 60}m';
  }

  TaskStatus _mapState(String state) {
    switch (state) {
      case 'completed':
        return TaskStatus.completed;
      case 'in_progress':
        return TaskStatus.ongoing;
      default:
        return TaskStatus.notAccepted;
    }
  }

  List<Map<String, dynamic>> _tasks = [];

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
                        final name = result['title']!;
                        final durationStr = result['duration']!;
                        
                        int durationMinutes = 0;
                        if (durationStr.contains('h')) {
                          final parts = durationStr.split('h');
                          durationMinutes = (int.tryParse(parts[0]) ?? 0) * 60;
                          if (parts.length > 1 && parts[1].contains('m')) {
                            durationMinutes += int.tryParse(parts[1].replaceAll('m', '').trim()) ?? 0;
                          }
                        } else if (durationStr.contains('m')) {
                          durationMinutes = int.tryParse(durationStr.replaceAll('m', '').trim()) ?? 0;
                        }

                        if (_childHash != null) {
                          int? remoteId;
                          if (_parentEmail != null && _parentPassword != null) {
                            final result = await _auth.createTask(
                              email: _parentEmail!,
                              password: _parentPassword!,
                              childHash: _childHash!,
                              name: name,
                              category: 'chore',
                              duration: durationMinutes,
                              rewardPoints: 3,
                            );
                            if (result['success'] == true) {
                              final task = result['task'] as Map<String, dynamic>?;
                              remoteId = task?['id'] as int?;
                            }
                          }
                          await _db.upsertTask(
                            childHash: _childHash!,
                            name: name,
                            category: 'Chore',
                            duration: durationMinutes * 60,
                            remoteId: remoteId,
                          );
                        }

                        setState(() {
                          _tasks.add({
                            'title': name,
                            'duration': result['duration'],
                            'status': TaskStatus.notAccepted,
                          });
                        });
                        if (_childHash != null) {
                          await _loadTasks();
                        }
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
                          onTap: () async {
                            final localId = task['localId'] as int?;
                            final remoteId = task['remote_id'] as int?;
                            if (localId != null) {
                              await _db.deleteTask(localId: localId);
                            }
                            if (remoteId != null && _parentEmail != null && _parentPassword != null && _childHash != null) {
                              await _auth.deleteTask(
                                email: _parentEmail!,
                                password: _parentPassword!,
                                childHash: _childHash!,
                                taskId: remoteId,
                              );
                            }
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
