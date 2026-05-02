import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';
import 'order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final ApiClient _client;
  static const _cacheBoxName = 'orders_cache';

  OrderRepositoryImpl(this._client);

  @override
  Future<PaginatedOrders> getOrders({String? cursor}) async {
    try {
      print('=== ORDERS REQUEST: ${ApiConstants.orders}');

      final response = await _client.dio.get(
        ApiConstants.orders,
        queryParameters: cursor != null ? {'cursor': cursor} : null,
      );

      print('=== ORDERS RESPONSE: ${response.statusCode}');

      final data = response.data as Map<String, dynamic>;

      // Извлекаем cursor из полного URL следующей страницы
      final nextUrl = data['next'] as String?;
      final nextCursor = _extractCursor(nextUrl);

      final results = (data['results'] as List)
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Кэшируем только первую страницу
      if (cursor == null) {
        await cacheOrders(results);
      }

      return PaginatedOrders(
        results: results,
        next: nextCursor,
        previous: data['previous'] as String?,
      );
    } on DioException catch (e) {
      print('=== ORDERS ERROR: ${e.type} ${e.message}');
      // Нет сети — читаем из Hive
      final cached = await getCachedOrders();
      return PaginatedOrders(results: cached);
    }
  }

  @override
  Future<List<Order>> getCachedOrders() async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);
      final jsonStrings = box.values.toList();

      return jsonStrings.map((jsonStr) {
        final map = Map<String, dynamic>.from(
          Uri.splitQueryString(
            jsonStr,
          ).map((k, v) => MapEntry(k, v as dynamic)),
        );
        return OrderModel.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cacheOrders(List<Order> orders) async {
    try {
      final box = await Hive.openBox<String>(_cacheBoxName);
      await box.clear();

      for (final order in orders) {
        await box.put(order.id, _orderToString(order));
      }
    } catch (_) {}
  }

  // Извлекаем cursor из полного URL
  String? _extractCursor(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['cursor'];
  }

  // Сохраняем заказ как строку key=value для Hive
  String _orderToString(Order order) {
    return [
      'id=${order.id}',
      'status=${order.status}',
      'status_display=${order.statusDisplay}',
      'order_type=${order.orderType}',
      'order_type_display=${order.orderTypeDisplay}',
      'created=${order.created}',
      'by_phone=${order.byPhone}',
      if (order.code != null) 'code=${order.code}',
      if (order.total != null) 'total=${order.total}',
      if (order.outletName != null) 'outlet=${order.outletName}',
      if (order.deliveryDate != null) 'delivery_date=${order.deliveryDate}',
      if (order.documentStatusDisplay != null)
        'document_status_display=${order.documentStatusDisplay}',
    ].join('&');
  }
}
