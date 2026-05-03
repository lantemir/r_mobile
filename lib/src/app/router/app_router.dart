import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Следим за состоянием авторизации
  // При изменении — роутер автоматически пересчитает редирект
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',

    // redirect вызывается перед каждым переходом
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';

      // Не залогинен — всегда на логин
      if (!isLoggedIn && !onLogin) return '/login';

      // Залогинен и стоит на логине — на главную
      if (isLoggedIn && onLogin) return '/home';

      // Всё ок — никуда не редиректим
      return null;
    },

    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      // Сюда будем добавлять новые экраны:
      GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
    ],
  );
});
