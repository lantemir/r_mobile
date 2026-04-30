import 'task.dart';

// Обёртка для пагинированного ответа Django
// Django CursorPagination возвращает:
// {
//   "next": "http://.../?cursor=xxx",  ← ссылка на след. страницу
//   "previous": "http://.../?cursor=yyy",
//   "results": [...]  ← сам список
// }

class PaginatedTasks {
  final List<Task> results;
  final String? next; // null если это последняя страница
  final String? previous;

  const PaginatedTasks({required this.results, this.next, this.previous});

  bool get hasMore => next != null;
}

abstract class TaskRepository {
  // Получить список задач с сервера
  // cursor — для пагинации (null = первая страница)
  Future<PaginatedTasks> getTasks({String? cursor});

  // Получить задачи из локального кэша (офлайн)
  Future<List<Task>> getCachedTasks();

  // Сохранить задачи в локальный кэш
  Future<void> cacheTasks(List<Task> tasks);
}
