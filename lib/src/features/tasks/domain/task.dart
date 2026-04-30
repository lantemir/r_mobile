class Task {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String statusDisplay; // человекочитаемый статус на русском
  final String? dueDate; // срок выполнения
  final bool isOverdue; // просрочена ли
  final String? comment;
  final String? outletName; // название торговой точки
  final String? completedAt;
  final bool isApproved;
  final String created;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.statusDisplay,
    this.dueDate,
    required this.isOverdue,
    this.comment,
    this.outletName,
    this.completedAt,
    required this.isApproved,
    required this.created,
  });

  // Цвет статуса — используем в UI
  // NEW, IN_PROGRESS, COMPLETED, NOT_COMPLETED
  bool get isCompleted => status == 'COMPLETED';
  bool get isNew => status == 'NEW';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isNotCompleted => status == 'NOT_COMPLETED';
}
