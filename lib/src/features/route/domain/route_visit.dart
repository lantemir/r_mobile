class RouteVisit {
  final String id;
  final String outletId;
  final String started;
  final String? ended;
  final String status;
  final String? comment;
  final String created;

  const RouteVisit({
    required this.id,
    required this.outletId,
    required this.started,
    this.ended,
    required this.status,
    this.comment,
    required this.created,
  });

  // Длительность визита
  String get duration {
    if (ended == null) return 'В процессе';
    final start = DateTime.tryParse(started);
    final end = DateTime.tryParse(ended!);
    if (start == null || end == null) return '';
    final diff = end.difference(start);
    if (diff.inMinutes < 1) return 'менее минуты';
    return '${diff.inMinutes} мин';
  }

  // Форматированная дата
  String get formattedDate {
    final dt = DateTime.tryParse(created);
    if (dt == null) return created;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  bool get isCompleted => ended != null;
}
