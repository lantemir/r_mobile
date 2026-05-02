import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order.dart';
import 'order_providers.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(ordersProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final statusFilter = ref.watch(orderStatusFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Применяем фильтр по статусу
    final filteredOrders = state.filtered(statusFilter);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Заказы',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (filteredOrders.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${filteredOrders.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // ── Фильтры по статусу ──
          _StatusFilter(),

          // ── Офлайн баннер ──
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

          // ── Основной контент ──
          Expanded(child: _buildBody(state, filteredOrders)),
        ],
      ),
    );
  }

  Widget _buildBody(OrdersState state, List<Order> orders) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && orders.isEmpty) {
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
              onPressed: () => ref.read(ordersProvider.notifier).loadOrders(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Заказов нет'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).loadOrders(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: orders.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _OrderCard(order: orders[index]);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// Фильтр по статусу
// ──────────────────────────────────────────

class _StatusFilter extends ConsumerWidget {
  // Статусы заказов из Django Order.Status
  static const _filters = [
    _FilterItem(null, 'Все'),
    _FilterItem('NEW', 'Новые'),
    _FilterItem('SENT', 'Отправлен'),
    _FilterItem('ACCEPTED', 'Принят'),
    _FilterItem('CANCELLED', 'Отменён'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(orderStatusFilterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = current == filter.status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref.read(orderStatusFilterProvider.notifier).state =
                  filter.status,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterItem {
  final String? status;
  final String label;
  const _FilterItem(this.status, this.label);
}

// ──────────────────────────────────────────
// Карточка заказа
// ──────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

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
            // ── Заголовок: номер + статус ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.code != null ? '№ ${order.code}' : 'Заказ без номера',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                _StatusBadge(status: order.status, label: order.statusDisplay),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Торговая точка ──
            if (order.outletName != null)
              _InfoRow(icon: Icons.storefront_rounded, text: order.outletName!),

            // ── Тип заказа ──
            _InfoRow(
              icon: Icons.category_rounded,
              text: order.orderTypeDisplay,
            ),

            // ── Дата доставки ──
            if (order.deliveryDate != null)
              _InfoRow(
                icon: Icons.local_shipping_rounded,
                text: 'Доставка: ${order.deliveryDate!.substring(0, 10)}',
              ),

            // ── Статус документа ──
            if (order.documentStatusDisplay != null)
              _InfoRow(
                icon: Icons.description_rounded,
                text: order.documentStatusDisplay!,
                color: colorScheme.onSurfaceVariant,
              ),

            // ── Заказ по телефону ──
            if (order.byPhone)
              _InfoRow(
                icon: Icons.phone_rounded,
                text: 'Заказ по телефону',
                color: Colors.blue,
              ),

            const SizedBox(height: 8),

            // ── Итоговая сумма ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  order.totalFormatted,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
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
      case 'ACCEPTED':
        return Colors.green.shade100;
      case 'SENT':
        return Colors.blue.shade100;
      case 'CANCELLED':
        return Colors.red.shade100;
      default: // NEW
        return Colors.grey.shade200;
    }
  }

  Color _textColor() {
    switch (status) {
      case 'ACCEPTED':
        return Colors.green.shade800;
      case 'SENT':
        return Colors.blue.shade800;
      case 'CANCELLED':
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
// Строка с иконкой
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
