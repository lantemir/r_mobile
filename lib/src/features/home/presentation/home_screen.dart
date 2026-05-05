// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              user: user,
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Разделы'),
                    SizedBox(height: 12),
                    _MenuGrid(),
                    SizedBox(height: 24),
                    _SectionTitle('Сегодня'),
                    SizedBox(height: 12),
                    _CountersGrid(),
                    SizedBox(height: 24),
                    _SectionTitle('Задачи'),
                    SizedBox(height: 8),
                    _PlaceholderCard(
                      icon: Icons.task_alt_rounded,
                      text:
                          'Здесь появятся задачи, которые вам назначены.\nПолучите актуальные данные с сервера.',
                    ),
                    SizedBox(height: 16),
                    _SectionTitle('Новости'),
                    SizedBox(height: 8),
                    _PlaceholderCard(
                      icon: Icons.newspaper_rounded,
                      text:
                          'Здесь появятся новости.\nПолучите актуальные данные с сервера.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 2) context.push('/analytics');
          if (index == 3) context.push('/sync');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Маршрут',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Аналитика',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync_rounded),
            label: 'Обмен',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

// ── Шапка ──

class _Header extends StatelessWidget {
  final dynamic user;
  final VoidCallback onLogout;
  const _Header({this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'МАРШРУТ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (user != null)
                  Text(
                    user.fullName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: onLogout,
            tooltip: 'Выйти',
          ),
        ],
      ),
    );
  }
}

// ── Сетка меню ──

class _MenuGrid extends StatelessWidget {
  const _MenuGrid();

  static const _items = [
    _MenuItem(Icons.list_alt_rounded, 'ТОВАРЫ', ''),
    _MenuItem(Icons.task_alt_rounded, 'ЗАДАЧИ', '/tasks'),
    _MenuItem(Icons.local_offer_rounded, 'АКЦИИ', ''),
    _MenuItem(Icons.receipt_long_rounded, 'НАКЛАДНЫЕ', ''),
    _MenuItem(Icons.shopping_cart_rounded, 'ЗАКАЗЫ', '/orders'),
    _MenuItem(Icons.book_rounded, 'ЖУРНАЛ', ''),
    _MenuItem(Icons.map_rounded, 'КАРТА', ''),
    _MenuItem(Icons.point_of_sale_rounded, 'КАССА', ''),
    _MenuItem(Icons.people_rounded, 'КЛИЕНТЫ', ''),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _items.map((item) => _MenuCard(item: item)).toList(),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route; // пустая строка = ещё не реализовано
  const _MenuItem(this.icon, this.label, this.route);
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRoute = item.route.isNotEmpty;

    return InkWell(
      // Навигация только если роут задан
      onTap: hasRoute ? () => context.push(item.route) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Серая рамка если не реализовано
            color: hasRoute
                ? colorScheme.outlineVariant
                : colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: hasRoute
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.3),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: hasRoute
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Счётчики ──

class _CountersGrid extends StatelessWidget {
  const _CountersGrid();

  static const _counters = [
    _CounterItem(Icons.storefront_rounded, 'ВИЗИТЫ', '0|0', Colors.purple),
    _CounterItem(
      Icons.shopping_bag_rounded,
      'МЕРЧАНДАЙЗИНГ',
      '0|0',
      Colors.blue,
    ),
    _CounterItem(Icons.shopping_cart_rounded, 'ЗАКАЗЫ', '0|0', Colors.green),
    _CounterItem(Icons.payments_rounded, 'СУММА', '0.00 ₸', Colors.teal),
    _CounterItem(Icons.poll_rounded, 'ОПРОСЫ', '0|0', Colors.orange),
    _CounterItem(Icons.undo_rounded, 'ВОЗВРАТЫ', '0.00 ₸', Colors.red),
    _CounterItem(Icons.receipt_rounded, 'ПКО', '0|0', Colors.amber),
    _CounterItem(Icons.camera_alt_rounded, 'ФОТООТЧЕТ', '0|0', Colors.indigo),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _counters.map((c) => _CounterTile(item: c)).toList(),
    );
  }
}

class _CounterItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _CounterItem(this.icon, this.label, this.value, this.color);
}

class _CounterTile extends StatelessWidget {
  final _CounterItem item;
  const _CounterTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PlaceholderCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
