import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/catalog_item.dart';
import '../domain/catalog_repository.dart';
import 'catalog_item_model.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final ApiClient _client;

  CatalogRepositoryImpl(this._client);

  @override
  Future<List<CatalogItem>> getCatalogItems({
    String? outletId,
    String? search,
  }) async {
    try {
      // Загружаем пять источников параллельно
      final results = await Future.wait([
        _client.dio.get('route/product-matches/'),
        _client.dio.get('route/prices/'),
        _client.dio.get('route/inventories/'),
        _client.dio.get('route/activity-matches/'),
        _client.dio.get('route/activity-match-products/'),
      ]);

      final productMatches = results[0].data as List;
      final prices = results[1].data as List;
      final inventories = results[2].data as List;
      final activityMatches = results[3].data as List;
      final activityMatchProducts = results[4].data as List;

      print('=== MATCHES: ${productMatches.length}');
      print('=== PRICES: ${prices.length}');
      print('=== INVENTORIES: ${inventories.length}');
      print('=== ACTIVITY MATCHES: ${activityMatches.length}');
      print('=== ACTIVITY MATCH PRODUCTS: ${activityMatchProducts.length}');

      // Map: activity_match_id → title акции
      final activityTitleMap = <String, String>{};
      for (final am in activityMatches) {
        final m = am as Map<String, dynamic>;
        activityTitleMap[m['id'] as String] = m['title'] as String? ?? '';
      }

      // Map: product_match_id → price
      final priceMap = <String, String>{};
      for (final p in prices) {
        final price = p as Map<String, dynamic>;
        final id = price['product_match'] as String?;
        final val = price['price'] as String?;
        if (id != null && val != null) priceMap[id] = val;
      }

      // Map: product_match_id → {activityMatchId, price}
      // Берём только BUY-тип — это цена/акция на сам покупаемый товар,
      // BONUS — это отдельный бонусный товар (N+M), не относится к цене этой позиции
      final activityForProductMatch = <String, Map<String, dynamic>>{};
      for (final amp in activityMatchProducts) {
        final p = amp as Map<String, dynamic>;
        if (p['product_type'] != 'BUY') continue;
        final productMatchId = p['product_match'] as String;
        activityForProductMatch[productMatchId] = {
          'activityMatchId': p['activity_match'] as String,
          'price': p['price'], // может быть null — тогда акция не меняет цену
        };
      }

      // Map: product_match_id → {quantity, reserved}
      final stockMap = <String, Map<String, double>>{};
      for (final inv in inventories) {
        final i = inv as Map<String, dynamic>;
        final id = i['product_match'] as String?;
        if (id != null) {
          stockMap[id] = {
            'quantity': (i['quantity'] as num?)?.toDouble() ?? 0,
            'reserved': (i['reserved'] as num?)?.toDouble() ?? 0,
          };
        }
      }

      // Фильтр по поиску
      var matches = productMatches;
      if (search != null && search.isNotEmpty) {
        matches = matches.where((e) {
          final title = (e as Map)['title'] as String? ?? '';
          return title.toLowerCase().contains(search.toLowerCase());
        }).toList();
      }

      // Соединяем всё вместе
      return matches.map((e) {
        final match = e as Map<String, dynamic>;
        final id = match['id'] as String;
        final price = priceMap[id] ?? '0';
        final stock = stockMap[id];
        final activity = activityForProductMatch[id];

        String? activityMatchId;
        String? activityName;
        String? activityPriceStr;

        if (activity != null) {
          activityMatchId = activity['activityMatchId'] as String?;
          activityPriceStr = activity['price']?.toString();
          if (activityMatchId != null) {
            activityName = activityTitleMap[activityMatchId];
          }
        }

        return CatalogItemModel.fromJsonWithPrice(
          match,
          price,
          quantity: stock?['quantity'] ?? 0,
          reserved: stock?['reserved'] ?? 0,
          activityMatchId: activityMatchId,
          activityName: activityName,
          activityPrice: activityPriceStr,
        );
      }).toList();
    } on DioException catch (e) {
      print('=== CATALOG ERROR: ${e.response?.data}');
      throw Exception(ApiClient.parseError(e));
    }
  }
}
