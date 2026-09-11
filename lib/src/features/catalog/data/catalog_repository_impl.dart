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

      final today = DateTime.now();
      bool isWithinActivityDates(Map<String, dynamic> m) {
        final started = DateTime.tryParse(m['started']?.toString() ?? '');
        final ended = DateTime.tryParse(m['ended']?.toString() ?? '');
        if (started != null && today.isBefore(started)) return false;
        // ended — дата, а не момент времени: акция ещё действует весь этот день
        if (ended != null && today.isAfter(ended.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }

      // Map: activity_match_id → title акции
      final activityTitleMap = <String, String>{};
      // Map: activity_match_id → id активной механики (ActivitySetting), для заказа
      final activitySettingIdMap = <String, String>{};
      // Map: activity_match_id → параметры механики N+M, если она есть
      final nPlusMSettingMap = <String, Map<String, dynamic>>{};

      for (final am in activityMatches) {
        final m = am as Map<String, dynamic>;
        if (!isWithinActivityDates(m)) continue; // акция истекла или ещё не началась

        final activityMatchId = m['id'] as String;
        activityTitleMap[activityMatchId] = m['title'] as String? ?? '';

        final settings = (m['settings'] as List?) ?? const [];
        Map<String, dynamic>? activeSetting;
        for (final s in settings) {
          final setting = s as Map<String, dynamic>;
          if (setting['is_active'] == true) {
            activeSetting = setting;
          }
          if (setting['setting_type'] == 'N_PLUS_M') {
            nPlusMSettingMap[activityMatchId] = setting;
          }
        }
        // Если явно активной механики нет — берём первую как есть
        activeSetting ??= settings.isNotEmpty
            ? settings.first as Map<String, dynamic>
            : null;
        if (activeSetting?['id'] != null) {
          activitySettingIdMap[activityMatchId] =
              activeSetting!['id'] as String;
        }
      }

      // Map: product_match_id → price
      final priceMap = <String, String>{};
      for (final p in prices) {
        final price = p as Map<String, dynamic>;
        final id = price['product_match'] as String?;
        final val = price['price'] as String?;
        if (id != null && val != null) priceMap[id] = val;
      }

      // Map: product_match_id → title (нужно для названия бонусного товара)
      final titleByProductMatch = <String, String>{};
      for (final m in productMatches) {
        final match = m as Map<String, dynamic>;
        final id = match['id'] as String?;
        if (id != null) {
          titleByProductMatch[id] = match['title'] as String? ?? '';
        }
      }

      // Map: product_match_id → {activityMatchId, price} — цена на сам покупаемый товар
      // Map: activity_match_id → product_match_id бонусного товара (механика N+M)
      final activityForProductMatch = <String, Map<String, dynamic>>{};
      final bonusProductMatchForActivityMatch = <String, String>{};
      for (final amp in activityMatchProducts) {
        final p = amp as Map<String, dynamic>;
        final activityMatchId = p['activity_match'] as String?;
        final productMatchId = p['product_match'] as String?;
        if (activityMatchId == null || productMatchId == null) continue;
        if (!activityTitleMap.containsKey(activityMatchId)) {
          continue; // акция отфильтрована выше (истекла / не началась)
        }

        if (p['product_type'] == 'BUY') {
          activityForProductMatch[productMatchId] = {
            'activityMatchId': activityMatchId,
            'price': p['price'], // может быть null — тогда акция не меняет цену
          };
        } else if (p['product_type'] == 'BONUS') {
          bonusProductMatchForActivityMatch[activityMatchId] = productMatchId;
        }
      }

      // Map: product_match_id → {quantity, reserved}
      final stockMap = <String, Map<String, double>>{};
      // Map: product_match_id → id склада, на котором физически лежит остаток.
      // Нужен при оформлении заказа — сервер требует остаток именно на складе заказа,
      // а не просто где-то в системе (см. check_product_match_inventory на бэкенде).
      final warehouseByProductMatch = <String, String>{};
      for (final inv in inventories) {
        final i = inv as Map<String, dynamic>;
        final id = i['product_match'] as String?;
        if (id != null) {
          stockMap[id] = {
            'quantity': (i['quantity'] as num?)?.toDouble() ?? 0,
            'reserved': (i['reserved'] as num?)?.toDouble() ?? 0,
          };
          final warehouseId = i['warehouse'] as String?;
          if (warehouseId != null) {
            warehouseByProductMatch[id] = warehouseId;
          }
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
        String? activitySettingId;
        String? activityName;
        String? activityPriceStr;
        BonusOffer? bonus;

        if (activity != null) {
          activityMatchId = activity['activityMatchId'] as String?;
          activityPriceStr = activity['price']?.toString();
          if (activityMatchId != null) {
            activityName = activityTitleMap[activityMatchId];
            activitySettingId = activitySettingIdMap[activityMatchId];

            final nPlusM = nPlusMSettingMap[activityMatchId];
            final bonusProductMatchId =
                bonusProductMatchForActivityMatch[activityMatchId];
            if (nPlusM != null && bonusProductMatchId != null) {
              final buyQuantity = (nPlusM['buy_quantity'] as num?)?.toInt();
              final bonusQuantity =
                  (nPlusM['bonus_quantity'] as num?)?.toInt();
              final nPlusMSettingId = nPlusM['id'] as String?;
              if (buyQuantity != null &&
                  buyQuantity > 0 &&
                  bonusQuantity != null &&
                  bonusQuantity > 0 &&
                  nPlusMSettingId != null) {
                bonus = BonusOffer(
                  productMatchId: bonusProductMatchId,
                  title: titleByProductMatch[bonusProductMatchId] ?? '',
                  buyQuantity: buyQuantity,
                  bonusQuantity: bonusQuantity,
                  oneTimePurchase: nPlusM['one_time_purchase'] == true,
                  activitySettingId: nPlusMSettingId,
                  warehouseId: warehouseByProductMatch[bonusProductMatchId],
                );
              }
            }
          }
        }

        return CatalogItemModel.fromJsonWithPrice(
          match,
          price,
          quantity: stock?['quantity'] ?? 0,
          reserved: stock?['reserved'] ?? 0,
          activityMatchId: activityMatchId,
          activitySettingId: activitySettingId,
          activityName: activityName,
          activityPrice: activityPriceStr,
          bonus: bonus,
          warehouseId: warehouseByProductMatch[id],
        );
      }).toList();
    } on DioException catch (e) {
      print('=== CATALOG ERROR: ${e.response?.data}');
      throw Exception(ApiClient.parseError(e));
    }
  }
}
