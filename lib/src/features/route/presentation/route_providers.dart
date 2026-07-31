import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/auth_providers.dart';
import '../data/route_repository_impl.dart';
import '../domain/route_day.dart';
import '../domain/route_info.dart';
import '../domain/route_outlet.dart';
import '../domain/route_repository.dart';

// ─────────────────────────────────────────
// 1. Репозиторий
// ─────────────────────────────────────────

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepositoryImpl(ref.read(apiClientProvider));
});

// ─────────────────────────────────────────
// 2. Состояние экрана маршрута
// ─────────────────────────────────────────

class RouteState {
  final bool isLoading;
  final String? error;
  final RouteInfo? routeInfo; // данные маршрута
  final List<RouteDay> days; // дни маршрута
  final List<RouteOutlet> outlets; // все торговые точки

  const RouteState({
    this.isLoading = false,
    this.error,
    this.routeInfo,
    this.days = const [],
    this.outlets = const [],
  });

  RouteState copyWith({
    bool? isLoading,
    String? error,
    RouteInfo? routeInfo,
    List<RouteDay>? days,
    List<RouteOutlet>? outlets,
    bool clearError = false,
  }) {
    return RouteState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      routeInfo: routeInfo ?? this.routeInfo,
      days: days ?? this.days,
      outlets: outlets ?? this.outlets,
    );
  }

  // ── Ключевой метод — JOIN дней и точек ──
  // Для каждого дня находим полные данные его точек
  // RouteDay содержит outletIds → ищем в outlets по id
  List<RouteOutlet> getOutletsForDay(RouteDay day) {
    return day.outletIds
        .map((id) => outlets.where((o) => o.id == id).firstOrNull)
        .whereType<RouteOutlet>() // убираем null если точка не найдена
        .toList();
  }

  // Дни отфильтрованные по текущей неделе
  // Для двухнедельного маршрута важно показывать только нужную неделю
  List<RouteDay> get currentWeekDays {
    if (days.isEmpty) return [];
    return days;
  }
}

// ─────────────────────────────────────────
// 3. Notifier
// ─────────────────────────────────────────

class RouteNotifier extends StateNotifier<RouteState> {
  final RouteRepository _repository;

  RouteNotifier(this._repository) : super(const RouteState()) {
    loadRoute();
  }

  Future<void> loadRoute() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Загружаем все три эндпоинта параллельно
      // Future.wait — запускает все три запроса одновременно
      // Это быстрее чем последовательно (await + await + await)
      final results = await Future.wait([
        _repository.getRouteInfo(), // запрос 1
        _repository.getRouteDays(), // запрос 2
        _repository.getRouteOutlets(), // запрос 3
      ]);

      state = state.copyWith(
        isLoading: false,
        routeInfo: results[0] as RouteInfo,
        days: results[1] as List<RouteDay>,
        outlets: results[2] as List<RouteOutlet>,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>((ref) {
  return RouteNotifier(ref.read(routeRepositoryProvider));
});
