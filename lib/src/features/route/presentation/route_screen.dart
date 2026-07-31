import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/route_day.dart';
import '../domain/route_outlet.dart';
import 'outlet_detail_screen.dart';
import 'route_providers.dart';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          state.routeInfo != null
              ? 'МАРШРУТ ${state.routeInfo!.number}'
              : 'МАРШРУТ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(routeProvider.notifier).loadRoute(),
          ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, RouteState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
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
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(routeProvider.notifier).loadRoute(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (state.days.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Дни маршрута не найдены'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(routeProvider.notifier).loadRoute(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.routeInfo != null)
            _RouteInfoCard(routeInfo: state.routeInfo!),
          const SizedBox(height: 16),
          ...state.currentWeekDays.map(
            (day) =>
                _RouteDayCard(day: day, outlets: state.getOutletsForDay(day)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Карточка информации о маршруте
// ──────────────────────────────────────────

class _RouteInfoCard extends StatelessWidget {
  final dynamic routeInfo;
  const _RouteInfoCard({required this.routeInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: colorScheme.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeInfo.displayTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  routeInfo.isTwoWeeks
                      ? '2 недели • Неделя ${routeInfo.currentWeek + 1}'
                      : '1 неделя',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Карточка дня маршрута — раскрывается
// ──────────────────────────────────────────

class _RouteDayCard extends StatefulWidget {
  final RouteDay day;
  final List<RouteOutlet> outlets;

  const _RouteDayCard({required this.day, required this.outlets});

  @override
  State<_RouteDayCard> createState() => _RouteDayCardState();
}

class _RouteDayCardState extends State<_RouteDayCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Заголовок дня
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.day.dayDisplayRu.substring(0, 2),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.day.dayDisplayRu,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.outlets.length} торговых точек',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Список точек
          if (_isExpanded) ...[
            Divider(height: 1, color: colorScheme.outlineVariant),
            if (widget.outlets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Нет торговых точек',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              ...widget.outlets.asMap().entries.map((entry) {
                final index = entry.key;
                final outlet = entry.value;
                return _OutletTile(
                  outlet: outlet,
                  index: index + 1,
                  isLast: index == widget.outlets.length - 1,
                );
              }),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Строка торговой точки — отдельный класс!
// ──────────────────────────────────────────

class _OutletTile extends StatelessWidget {
  final RouteOutlet outlet;
  final int index;
  final bool isLast;

  const _OutletTile({
    required this.outlet,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  OutletDetailScreen(outlet: outlet, plannedOrder: index),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Номер точки
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outlet.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (outlet.address != null &&
                          outlet.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                outlet.address!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (outlet.decisionMaker != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${outlet.decisionMaker!.fullName} • ${outlet.decisionMaker!.phoneNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // Разделитель — isLast доступна напрямую!
        if (!isLast)
          Divider(height: 1, indent: 56, color: colorScheme.outlineVariant),
      ],
    );
  }
}
