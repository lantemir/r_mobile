import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import 'task_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Слушаем скролл — когда доходим до конца, грузим следующую страницу
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    // Если проскроллили до 200px от конца — грузим ещё
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(tasksProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Задачи',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Счётчик задач
          if (state.tasks.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${state.tasks.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // Офлайн баннер
          if (state.isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Офлайн — показаны кэшированные данные',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),

          // Основной контент
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(TasksState state) {
    // Первая загрузка
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ошибка и нет кэша
    if (state.error != null && state.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(tasksProvider.notifier).loadTasks(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    // Пустой список
    if (state.tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Задач нет'),
          ],
        ),
      );
    }

    // Список задач с pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => ref.read(tasksProvider.notifier).loadTasks(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        // +1 для индикатора загрузки внизу
        itemCount: state.tasks.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Последний элемент — спиннер пагинации
          if (index == state.tasks.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return _TaskCard(task: state.tasks[index]);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// Карточка задачи
// ──────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + статус
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: task.status, label: task.statusDisplay),
              ],
            ),

            // Описание
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Торговая точка
            if (task.outletName != null)
              _InfoRow(icon: Icons.storefront_rounded, text: task.outletName!),

            // Срок выполнения
            if (task.dueDate != null)
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                text: task.dueDate!,
                // Красный если просрочена
                color: task.isOverdue ? Colors.red : null,
              ),

            // Комментарий
            if (task.comment != null && task.comment!.isNotEmpty)
              _InfoRow(icon: Icons.comment_outlined, text: task.comment!),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Бейдж статуса
// ──────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  Color _bgColor() {
    switch (status) {
      case 'COMPLETED':
        return Colors.green.shade100;
      case 'IN_PROGRESS':
        return Colors.blue.shade100;
      case 'NOT_COMPLETED':
        return Colors.red.shade100;
      default: // NEW
        return Colors.grey.shade200;
    }
  }

  Color _textColor() {
    switch (status) {
      case 'COMPLETED':
        return Colors.green.shade800;
      case 'IN_PROGRESS':
        return Colors.blue.shade800;
      case 'NOT_COMPLETED':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textColor(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Строка с иконкой и текстом
// ──────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: effectiveColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
