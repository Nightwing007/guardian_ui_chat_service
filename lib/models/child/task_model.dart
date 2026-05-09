/// Represents the lifecycle state of a task.
enum TaskState { initial, accepted, inProgress, completed }

class TaskModel {
  final int id;
  final String name;
  final String category;
  final String timerTime;

  /// Mutable so that screens can update state in the central DB.
  TaskState state;

  TaskModel({
    required this.id,
    required this.name,
    required this.category,
    required this.timerTime,
    required this.state,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      timerTime: json['timerTime'] as String,
      state: _parseState(json['state'] as String),
    );
  }

  static TaskState _parseState(String state) {
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
}
