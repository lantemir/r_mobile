import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/presentation/order_providers.dart';
import '../../tasks/presentation/task_providers.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            floating: true,
            pinned: true,
            title: const Text(
              'ОБМЕН',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(child: Text('ПОЛУЧИТЬ')),
                Tab(child: Text('ОТПРАВИТЬ')),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [_ReceiveTab(), _UploadTab()],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Вкладка ПОЛУЧИТЬ
// ──────────────────────────────────────────

class _ReceiveTab extends ConsumerStatefulWidget {
  const _ReceiveTab();

  @override
  ConsumerState<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends ConsumerState<_ReceiveTab> {
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;
  DateTime? _lastSync;

  // Шаги синхронизации — как в оригинале
  final List<_SyncStep> _steps = [
    _SyncStep(label: 'Задачи', icon: Icons.task_alt_rounded),
    _SyncStep(label: 'Заказы', icon: Icons.shopping_cart_rounded),
  ];
  int _currentStep = -1;

  Future<void> _startReceive() async {
    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _error = null;
      _currentStep = 0;
    });

    try {
      // Шаг 1 — Задачи
      setState(() => _currentStep = 0);
      await ref.read(tasksProvider.notifier).loadTasks();
      await Future.delayed(const Duration(milliseconds: 400));

      // Шаг 2 — Заказы
      setState(() => _currentStep = 1);
      await ref.read(ordersProvider.notifier).loadOrders();
      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _currentStep = -1;
        _lastSync = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _currentStep = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Карточка синхронизации ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Иконка + статус
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSuccess
                            ? Colors.green.shade50
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.download_rounded,
                        color: _isSuccess ? Colors.green : colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSuccess
                                ? 'Данные успешно загружены'
                                : _isLoading
                                ? 'Загружаем данные...'
                                : 'Получите актуальные данные',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (_lastSync != null)
                            Text(
                              '${_lastSync!.day.toString().padLeft(2, '0')}.${_lastSync!.month.toString().padLeft(2, '0')}.${_lastSync!.year} '
                              '${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Прогресс бар
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _isLoading
                        ? (_currentStep + 1) / _steps.length
                        : _isSuccess
                        ? 1.0
                        : 0.0,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isSuccess ? Colors.green : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Шаги
                if (_isLoading) ...[
                  ..._steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    final isDone = i < _currentStep;
                    final isCurrent = i == _currentStep;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : isCurrent
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isDone
                                ? Colors.green
                                : isCurrent
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            step.icon,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            step.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCurrent
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Ошибка
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Кнопки ПОДРОБНЕЕ и ПОЛУЧИТЬ
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Показываем детали
                        _showDetails(context);
                      },
                      child: Text(
                        'ПОДРОБНЕЕ',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isLoading ? null : _startReceive,
                      child: Text(
                        'ПОЛУЧИТЬ',
                        style: TextStyle(
                          color: _isLoading
                              ? colorScheme.onSurfaceVariant
                              : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Что синхронизируется ──
          _SectionTitle('Что синхронизируется'),
          const SizedBox(height: 12),

          _DataSourceTile(
            icon: Icons.task_alt_rounded,
            label: 'Задачи',
            count: ref.watch(tasksProvider).tasks.length,
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _DataSourceTile(
            icon: Icons.shopping_cart_rounded,
            label: 'Заказы',
            count: ref.watch(ordersProvider).orders.length,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Подробности синхронизации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(step.icon, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Text(step.label, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Вкладка ОТПРАВИТЬ
// ──────────────────────────────────────────

class _UploadTab extends ConsumerWidget {
  const _UploadTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tasksCount = ref.watch(tasksProvider).tasks.length;
    final ordersCount = ref.watch(ordersProvider).orders.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.upload_rounded,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Синхронизация не была проведена\nОтправка',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'ПОДРОБНЕЕ',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: null,
                      child: Text(
                        'ОТПРАВИТЬ',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Всего документов'),
          const SizedBox(height: 12),
          // Таблица счётчиков как в оригинале
          _CounterTable(
            items: [
              _CounterRow('Визиты', '0', '0', Colors.purple),
              _CounterRow('Заказы', '$ordersCount', '0', Colors.green),
              _CounterRow('Фотоотчёты', '0', '0', Colors.indigo),
              _CounterRow('Мерчандайзинг', '0', '0', Colors.blue),
              _CounterRow('Накладные', '0', '0', Colors.orange),
              _CounterRow('Кассовые чеки', '0', '0', Colors.teal),
              _CounterRow('Замена', '0', '0', Colors.grey),
              _CounterRow('Возврат', '0', '0', Colors.red),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Вспомогательные виджеты
// ──────────────────────────────────────────

class _SyncStep {
  final String label;
  final IconData icon;
  const _SyncStep({required this.label, required this.icon});
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DataSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _DataSourceTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterTable extends StatelessWidget {
  final List<_CounterRow> items;
  const _CounterTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: item.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      item.sent,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      ' | ',
                      style: TextStyle(color: colorScheme.outlineVariant),
                    ),
                    Text(
                      item.error,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                Divider(height: 1, color: colorScheme.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CounterRow {
  final String label;
  final String sent;
  final String error;
  final Color color;

  const _CounterRow(this.label, this.sent, this.error, this.color);
}
