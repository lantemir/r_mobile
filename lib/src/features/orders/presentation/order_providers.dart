import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/auth_providers.dart';
import '../data/order_repository_impl.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';

// ─────────────────────────────────────────
// 1. Репозиторий
// ─────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.read(apiClientProvider));
});

// ─────────────────────────────────────────
// 2. Фильтр по статусу
// null = показать все
// ─────────────────────────────────────────

final orderStatusFilterProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────
// 3. Состояние экрана заказов
// ─────────────────────────────────────────

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? nextCursor;
  final bool isOffline;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.nextCursor,
    this.isOffline = false,
  });

  // Отфильтрованный список — применяется в UI
  List<Order> filtered(String? statusFilter) {
    if (statusFilter == null) return orders;
    return orders.where((o) => o.status == statusFilter).toList();
  }

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? nextCursor,
    bool? isOffline,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ─────────────────────────────────────────
// 4. Notifier
// ─────────────────────────────────────────

class OrdersNotifier extends StateNotifier<OrdersState> {
  final OrderRepository _repository;

  OrdersNotifier(this._repository) : super(const OrdersState()) {
    loadOrders();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );

    try {
      final result = await _repository.getOrders();
      state = state.copyWith(
        isLoading: false,
        orders: result.results,
        nextCursor: result.next,
        isOffline: false,
      );
    } catch (e) {
      final cached = await _repository.getCachedOrders();
      state = state.copyWith(
        isLoading: false,
        orders: cached,
        isOffline: true,
        error: cached.isEmpty ? 'Нет подключения к серверу' : null,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _repository.getOrders(cursor: state.nextCursor);
      state = state.copyWith(
        isLoadingMore: false,
        orders: [...state.orders, ...result.results],
        nextCursor: result.next,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((
  ref,
) {
  return OrdersNotifier(ref.read(orderRepositoryProvider));
});
