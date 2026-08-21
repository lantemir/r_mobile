import 'order.dart';
import 'create_order_params.dart';

class PaginatedOrders {
  final List<Order> results;
  final String? next;
  final String? previous;

  const PaginatedOrders({required this.results, this.next, this.previous});

  bool get hasMore => next != null;
}

abstract class OrderRepository {
  // Получить список заказов с сервера
  Future<PaginatedOrders> getOrders({String? cursor});

  // Получить из кэша (офлайн)
  Future<List<Order>> getCachedOrders();

  // Сохранить в кэш
  Future<void> cacheOrders(List<Order> orders);

  // Создать новый заказ с товарами из корзины
  Future<Order> createOrder(CreateOrderParams params);
}
