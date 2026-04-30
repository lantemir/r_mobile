import '../domain/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.title,
    super.description,
    required super.status,
    required super.statusDisplay,
    super.dueDate,
    required super.isOverdue,
    super.comment,
    super.outletName,
    super.completedAt,
    required super.isApproved,
    required super.created,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    // outlet — вложенный объект {"id": 1, "name": "Магазин"}
    final outlet = json['outlet'] as Map<String, dynamic>?;

    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'NEW',
      // status_display приходит на русском: "Новая", "Выполнена"
      statusDisplay: json['status_display'] as String? ?? '',
      dueDate: json['due_date'] as String?,
      isOverdue: json['is_overdue'] as bool? ?? false,
      comment: json['comment'] as String?,
      // Достаём название точки из вложенного объекта
      outletName: outlet?['name'] as String?,
      completedAt: json['completed_at'] as String?,
      isApproved: json['is_approved'] as bool? ?? false,
      created: json['created'] as String? ?? '',
    );
  }
}
