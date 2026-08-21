import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';
import '../domain/create_order_params.dart';
import 'order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final ApiClient _client;
  static const _cacheBoxName = 'orders_cache';

  OrderRepositoryImpl(this._client);

  @override
  Future<PaginatedOrders> getOrders({String? cursor}) async {
    try {
      print('=== ORDERS REQUEST: ${ApiConstants.routeOrders}');

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

  @override
  Future<Order> createOrder(CreateOrderParams params) async {
    // Загружаем справочники
    final results = await Future.wait([
      _client.dio.get('route/price-types/'),
      _client.dio.get('route/warehouses/'),
      _client.dio.get('route/payment-types/'),
    ]);

    final priceTypes = results[0].data as List;
    final warehouses = results[1].data as List;
    final paymentTypes = results[2].data as List;

    if (priceTypes.isEmpty) {
      throw Exception('Нет доступных типов цен');
    }
    if (warehouses.isEmpty) {
      throw Exception('Нет доступных складов');
    }
    if (paymentTypes.isEmpty) {
      throw Exception('Нет доступных типов оплаты');
    }

    // Договоры контрагента
    final contractsResp = await _client.dio.get(
      'route/contracts/',
      queryParameters: {'counterparty': params.counterpartyId},
    );
    final contracts = contractsResp.data as List;

    if (contracts.isEmpty) {
      throw Exception('У контрагента нет договоров');
    }

    const uuid = Uuid();

    final orderData = {
      'id': uuid.v4(),
      'outlet': params.outletId,
      'counterparty': params.counterpartyId,
      'contract': (contracts[0] as Map)['id'],
      'price_type': (priceTypes[0] as Map)['id'],
      'warehouse': (warehouses[0] as Map)['id'],
      'payment_type': (paymentTypes[0] as Map)['id'],
      'visit': params.visitId,
      'order_type': 'REGULAR_ORDER',
      'delivery_date': params.deliveryDate.toIso8601String().substring(0, 10),
      'comment': params.comment,
      'by_phone': false,
      'created': DateTime.now().toUtc().toIso8601String(),
      'contents': params.items
          .map(
            (item) => {
              'id': uuid.v4(),
              'product_match': item.productMatchId,
              'quantity': item.quantity.toString(),
              'created': DateTime.now().toUtc().toIso8601String(),
              if (item.activityMatchId != null)
                'activity_match': item.activityMatchId,
            },
          )
          .toList(),
    };

    print('=== ORDER PAYLOAD: $orderData'); // временно, для проверки акции

    final response = await _client.dio.post(
      'route/orders/',
      data: {
        'id': uuid.v4(),
        'outlet': params.outletId,
        'counterparty': params.counterpartyId,
        'contract': (contracts[0] as Map)['id'],
        'price_type': (priceTypes[0] as Map)['id'],
        'warehouse': (warehouses[0] as Map)['id'],
        'payment_type': (paymentTypes[0] as Map)['id'],
        'visit': params.visitId,
        'order_type': 'REGULAR_ORDER',
        'delivery_date': params.deliveryDate.toIso8601String().substring(0, 10),
        'comment': params.comment,
        'by_phone': false,
        'created': DateTime.now().toUtc().toIso8601String(),
        'contents': params.items
            .map(
              (item) => {
                'id': uuid.v4(),
                'product_match': item.productMatchId,
                'quantity': item.quantity.toString(),
                'created': DateTime.now().toUtc().toIso8601String(),
                // Передаём акцию, только если она есть у позиции
                if (item.activityMatchId != null)
                  'activity_match': item.activityMatchId,
              },
            )
            .toList(),
      },
    );

    final data = response.data as Map<String, dynamic>;

    // route/orders/ возвращает outlet как строку-ID (не вложенный объект),
    // поэтому строим минимальный Order вручную, без OrderModel.fromJson,
    // чтобы не ловить несовпадение форматов между эндпоинтами
    return Order(
      id: data['id'] as String,
      code: data['code'] as String?,
      status: data['status'] as String? ?? 'NEW',
      statusDisplay: data['status_display'] as String? ?? '',
      orderType: data['order_type'] as String? ?? '',
      orderTypeDisplay: data['order_type_display'] as String? ?? '',
      total: data['total']?.toString(),
      outletName: null, // здесь недоступно — outlet приходит как id
      deliveryDate: data['delivery_date'] as String?,
      documentStatusDisplay: data['document_status_display'] as String?,
      created: data['created'] as String? ?? '',
      byPhone: data['by_phone'] as bool? ?? false,
    );
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
