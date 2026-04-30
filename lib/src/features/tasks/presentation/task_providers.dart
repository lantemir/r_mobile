import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/auth_providers.dart';
import '../data/task_repository_impl.dart';
import '../domain/task.dart';
import '../domain/task_repository.dart';

// ─────────────────────────────────────────
// 1. Репозиторий
// ─────────────────────────────────────────

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.read(apiClientProvider));
});

// ─────────────────────────────────────────
// 2. Состояние экрана задач
// ─────────────────────────────────────────

class TasksState {
  final List<Task> tasks;
  final bool isLoading; // первая загрузка
  final bool isLoadingMore; // подгрузка следующей страницы
  final String? error;
  final String? nextCursor; // null = больше страниц нет
  final bool isOffline; // показываем кэш

  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.nextCursor,
    this.isOffline = false,
  });

  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? nextCursor,
    bool? isOffline,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ─────────────────────────────────────────
// 3. Notifier — управляет состоянием
// ─────────────────────────────────────────

class TasksNotifier extends StateNotifier<TasksState> {
  final TaskRepository _repository;

  TasksNotifier(this._repository) : super(const TasksState()) {
    // Загружаем задачи сразу при создании
    loadTasks();
  }

  // Первая загрузка / обновление (pull to refresh)
  Future<void> loadTasks() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );

    try {
      final result = await _repository.getTasks();

      state = state.copyWith(
        isLoading: false,
        tasks: result.results,
        nextCursor: result.next,
        // Если нет next и результаты пришли — значит онлайн
        isOffline: false,
      );
    } catch (e) {
      // Пробуем загрузить кэш
      final cached = await _repository.getCachedTasks();
      state = state.copyWith(
        isLoading: false,
        tasks: cached,
        isOffline: true,
        error: cached.isEmpty ? 'Нет подключения к серверу' : null,
      );
    }
  }

  // Подгрузка следующей страницы (при скролле вниз)
  Future<void> loadMore() async {
    // Не грузим если уже грузим или нет следующей страницы
    if (state.isLoadingMore || state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _repository.getTasks(cursor: state.nextCursor);

      state = state.copyWith(
        isLoadingMore: false,
        // Добавляем к уже загруженным
        tasks: [...state.tasks, ...result.results],
        nextCursor: result.next,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

// Финальный провайдер
final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(ref.read(taskRepositoryProvider));
});
