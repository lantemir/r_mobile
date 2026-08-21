import 'catalog_item.dart';

abstract class CatalogRepository {
  // GET /api/v1/route/order-contents/
  // Список товаров доступных для заказа
  // outlet — фильтр по торговой точке
  Future<List<CatalogItem>> getCatalogItems({String? outletId, String? search});
}
