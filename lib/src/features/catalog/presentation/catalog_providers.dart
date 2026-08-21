import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/auth_providers.dart';
import '../data/catalog_repository_impl.dart';
import '../domain/catalog_item.dart';
import '../domain/catalog_repository.dart';

// ─────────────────────────────────────────
// 1. Репозиторий
// ─────────────────────────────────────────

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(ref.read(apiClientProvider));
});

// ─────────────────────────────────────────
// 2. Состояние каталога
// ─────────────────────────────────────────

class CatalogState {
  final bool isLoading;
  final String? error;
  final List<CatalogItem> items; // все товары
  final List<CatalogItem> filtered; // после поиска
  final String searchQuery;

  const CatalogState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.filtered = const [],
    this.searchQuery = '',
  });

  CatalogState copyWith({
    bool? isLoading,
    String? error,
    List<CatalogItem>? items,
    List<CatalogItem>? filtered,
    String? searchQuery,
    bool clearError = false,
  }) {
    return CatalogState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      items: items ?? this.items,
      filtered: filtered ?? this.filtered,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  final CatalogRepository _repository;
  final String outletId;

  CatalogNotifier(this._repository, this.outletId)
    : super(const CatalogState()) {
    loadItems();
  }

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.getCatalogItems(outletId: outletId);
      state = state.copyWith(
        isLoading: false,
        items: items,
        filtered: items, // изначально показываем все
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // Поиск по названию товара
  void search(String query) {
    final filtered = query.isEmpty
        ? state.items
        : state.items
              .where(
                (item) =>
                    item.title.toLowerCase().contains(query.toLowerCase()) ||
                    (item.brand?.toLowerCase().contains(query.toLowerCase()) ??
                        false),
              )
              .toList();

    state = state.copyWith(searchQuery: query, filtered: filtered);
  }
}

// family — отдельный провайдер для каждой точки
final catalogProvider = StateNotifierProvider.autoDispose
    .family<CatalogNotifier, CatalogState, String>(
      (ref, outletId) =>
          CatalogNotifier(ref.read(catalogRepositoryProvider), outletId),
    );

// ─────────────────────────────────────────
// 3. Корзина — отдельный провайдер
// ─────────────────────────────────────────

class CartState {
  // Map: product_match_id → CartItem
  final Map<String, CartItem> items;

  const CartState({this.items = const {}});

  // Список товаров в корзине
  List<CartItem> get cartItems => items.values.toList();

  // Общая сумма
  double get total => items.values.fold(0, (sum, item) => sum + item.total);

  String get formattedTotal => '${total.toStringAsFixed(2)} ₸';

  // Количество позиций
  int get itemsCount => items.length;

  // Количество конкретного товара
  double quantityOf(String itemId) => items[itemId]?.quantity ?? 0;

  bool hasItem(String itemId) => items.containsKey(itemId);

  CartState copyWith({Map<String, CartItem>? items}) {
    return CartState(items: items ?? this.items);
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  // Добавить или обновить количество
  void setQuantity(CatalogItem item, double quantity) {
    final newItems = Map<String, CartItem>.from(state.items);
    if (quantity <= 0) {
      newItems.remove(item.id);
    } else {
      newItems[item.id] = CartItem(item: item, quantity: quantity);
    }
    state = state.copyWith(items: newItems);
  }

  // Увеличить на 1
  void increment(CatalogItem item) {
    final current = state.quantityOf(item.id);
    setQuantity(item, current + 1);
  }

  // Уменьшить на 1
  void decrement(CatalogItem item) {
    final current = state.quantityOf(item.id);
    setQuantity(item, current - 1);
  }

  // Очистить корзину
  void clear() {
    state = const CartState();
  }

  // Конвертируем корзину в contents для POST заказа
  List<Map<String, dynamic>> toOrderContents() {
    return state.cartItems
        .map(
          (cartItem) => {
            'product_match': cartItem.item.id,
            'quantity': cartItem.quantity.toString(),
          },
        )
        .toList();
  }
}

final cartProvider = StateNotifierProvider.autoDispose<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
