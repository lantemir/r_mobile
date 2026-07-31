import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/task.dart';
import '../domain/task_repository.dart';
import 'task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final ApiClient _client;
  static const _cacheBoxName = 'tasks_cache';

  TaskRepositoryImpl(this._client);

  @override
  Future<PaginatedTasks> getTasks({String? cursor}) async {
    try {
      // Если есть cursor — используем его как URL параметр
      print('=== TASKS REQUEST: ${ApiConstants.routeTasks}');
      final response = await _client.dio.get(
        ApiConstants.tasks,
        queryParameters: cursor != null ? {'cursor': cursor} : null,
      );
      print('=== TASKS RESPONSE: ${response.statusCode}');
      print('=== TASKS DATA TYPE: ${response.data.runtimeType}');

      final data = response.data as Map<String, dynamic>;
      print('=== TASKS KEYS: ${data.keys.toList()}');
      print('=== TASKS COUNT: ${(data['results'] as List).length}');

      if ((data['results'] as List).isNotEmpty) {
        print('=== FIRST TASK: ${data['results'][0]}');
      }

      // Django CursorPagination возвращает next как полный URL
      // Нам нужен только cursor из него
      final nextUrl = data['next'] as String?;
      final nextCursor = _extractCursor(nextUrl);

      final results = (data['results'] as List)
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Кэшируем первую страницу для офлайн-режима
      if (cursor == null) {
        await cacheTasks(results);
      }

      return PaginatedTasks(
        results: results,
        next: nextCursor,
        previous: data['previous'] as String?,
      );
    } on DioException catch (e) {
      // Нет сети — возвращаем кэш
      print('=== TASKS ERROR: ${e.type} ${e.message}');
      print('=== TASKS ERROR RESPONSE: ${e.response?.data}');
      final cached = await getCachedTasks();
      return PaginatedTasks(results: cached);
    }
  }

  @override
  Future<List<Task>> getCachedTasks() async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);
      final jsonStrings = box.values.toList();

      return jsonStrings.map((jsonStr) {
        final map = Map<String, dynamic>.from(
          Uri.splitQueryString(
            jsonStr,
          ).map((k, v) => MapEntry(k, v as dynamic)),
        );
        return TaskModel.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cacheTasks(List<Task> tasks) async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);
      await box.clear();

      // Сохраняем каждую задачу по её id
      for (final task in tasks) {
        await box.put(task.id.toString(), _taskToString(task));
      }
    } catch (_) {}
  }

  // Извлекаем cursor из полного URL
  // "http://10.0.2.2:8000/api/v1/tasks/?cursor=abc123" → "abc123"
  String? _extractCursor(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['cursor'];
  }

  // Простое сохранение задачи как строки key=value
  String _taskToString(Task task) {
    return [
      'id=${task.id}',
      'title=${task.title}',
      'status=${task.status}',
      'status_display=${task.statusDisplay}',
      'is_overdue=${task.isOverdue}',
      'is_approved=${task.isApproved}',
      'created=${task.created}',
      if (task.description != null) 'description=${task.description}',
      if (task.dueDate != null) 'due_date=${task.dueDate}',
      if (task.outletName != null) 'outlet=${task.outletName}',
      if (task.comment != null) 'comment=${task.comment}',
    ].join('&');
  }
}
