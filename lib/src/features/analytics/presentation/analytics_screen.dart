import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/presentation/order_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(ordersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Группируем заказы по дате создания
    // created приходит как "2026-03-05T10:00:00+05:00"
    // берём только дату "2026-03-05"
    final Map<String, int> ordersByDate = {};
    final Map<String, double> sumByDate = {};

    for (final order in ordersState.orders) {
      if (order.created.length >= 10) {
        final date = order.created.substring(0, 10);
        ordersByDate[date] = (ordersByDate[date] ?? 0) + 1;
        final total = double.tryParse(order.total ?? '0') ?? 0;
        sumByDate[date] = (sumByDate[date] ?? 0) + total;
      }
    }

    // Сортируем даты
    final sortedDates = ordersByDate.keys.toList()..sort();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Аналитика',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ordersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ordersState.orders.isEmpty
          ? const Center(child: Text('Нет данных для аналитики'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Карточки с итогами ──
                  _SummaryCards(
                    totalOrders: ordersState.orders.length,
                    totalSum: sumByDate.values.fold(0, (a, b) => a + b),
                  ),
                  const SizedBox(height: 24),

                  // ── График количества заказов ──
                  _ChartCard(
                    title: 'Заказы по датам',
                    subtitle: 'Количество заказов',
                    child: sortedDates.isEmpty
                        ? const Center(child: Text('Нет данных'))
                        : _OrdersBarChart(
                            dates: sortedDates,
                            values: sortedDates
                                .map((d) => ordersByDate[d]!.toDouble())
                                .toList(),
                            color: colorScheme.primary,
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ── График сумм ──
                  _ChartCard(
                    title: 'Суммы по датам',
                    subtitle: 'Сумма заказов (₸)',
                    child: sortedDates.isEmpty
                        ? const Center(child: Text('Нет данных'))
                        : _OrdersBarChart(
                            dates: sortedDates,
                            values: sortedDates
                                .map((d) => sumByDate[d] ?? 0)
                                .toList(),
                            color: Colors.teal,
                            isCurrency: true,
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ── Статусы заказов (pie chart) ──
                  _ChartCard(
                    title: 'Статусы заказов',
                    subtitle: 'Распределение по статусам',
                    height: 280,
                    child: _StatusPieChart(
                      orders: ordersState.orders
                          .map((o) => o.statusDisplay)
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────
// Карточки с итогами вверху
// ──────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final int totalOrders;
  final double totalSum;

  const _SummaryCards({required this.totalOrders, required this.totalSum});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.shopping_cart_rounded,
            label: 'Заказов',
            value: '$totalOrders',
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_rounded,
            label: 'Общая сумма',
            value: '${totalSum.toStringAsFixed(0)} ₸',
            color: Colors.teal,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Обёртка для графика
// ──────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final double height;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Bar chart — заказы или суммы по датам
// ──────────────────────────────────────────

class _OrdersBarChart extends StatelessWidget {
  final List<String> dates;
  final List<double> values;
  final Color color;
  final bool isCurrency;

  const _OrdersBarChart({
    required this.dates,
    required this.values,
    required this.color,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = dates[group.x];
              // Показываем короткую дату MM-DD
              final shortDate = date.length >= 10
                  ? date.substring(5, 10)
                  : date;
              final value = isCurrency
                  ? '${rod.toY.toStringAsFixed(0)} ₸'
                  : rod.toY.toInt().toString();
              return BarTooltipItem(
                '$shortDate\n$value',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final text = isCurrency
                    ? '${(value / 1000).toStringAsFixed(0)}к'
                    : value.toInt().toString();
                return Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= dates.length) return const SizedBox();
                // Показываем только MM-DD
                final date = dates[index];
                final shortDate = date.length >= 10
                    ? date.substring(5, 10)
                    : date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    shortDate,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.5),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          dates.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                color: color,
                width: dates.length > 10 ? 8 : 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Pie chart — статусы заказов
// ──────────────────────────────────────────

class _StatusPieChart extends StatelessWidget {
  final List<String> orders;

  const _StatusPieChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Считаем количество каждого статуса
    final Map<String, int> statusCount = {};
    for (final status in orders) {
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    final entries = statusCount.entries.toList();

    return Row(
      children: [
        // Pie chart
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(entries.length, (i) {
                final entry = entries[i];
                final color = colors[i % colors.length];
                final percent = (entry.value / orders.length * 100)
                    .toStringAsFixed(1);
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: color,
                  title: '$percent%',
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),

        // Легенда
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.key} (${entry.value})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
