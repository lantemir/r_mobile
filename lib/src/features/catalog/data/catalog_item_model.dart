import '../domain/catalog_item.dart';

class CatalogItemModel extends CatalogItem {
  const CatalogItemModel({
    required super.id,
    required super.productId,
    required super.title,
    super.brand,
    super.photoUrl,
    super.unit,
    required super.price,
    super.priceTypeName,
    super.activityName,
    super.activityMatchId,
    super.activityPrice,
    super.stock,
    super.reserved,
  });

  factory CatalogItemModel.fromJsonWithPrice(
    Map<String, dynamic> json,
    String priceStr, {
    double quantity = 0,
    double reserved = 0,
    String? activityMatchId,
    String? activityName,
    String? activityPrice,
  }) {
    final double price = double.tryParse(priceStr) ?? 0;

    String? brandTitle;
    final brand = json['brand'];
    if (brand is Map) {
      brandTitle = brand['title'] as String?;
    }

    // Акционная цена приходит строкой из ActivityProduct.price (может быть null —
    // тогда акция есть, но цену не меняет, просто бейдж/промо)
    final double? parsedActivityPrice = activityPrice != null
        ? double.tryParse(activityPrice)
        : null;

    return CatalogItemModel(
      id: json['id'] as String,
      productId: json['id'] as String,
      title: json['title'] as String? ?? '',
      brand: brandTitle,
      photoUrl: null,
      unit: null,
      price: price,
      priceTypeName: null,
      activityName: activityName,
      activityMatchId: activityMatchId,
      activityPrice: parsedActivityPrice,
      stock: quantity,
      reserved: reserved,
    );
  }

  factory CatalogItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final brand = product?['brand'] as Map<String, dynamic>?;
    final unit = product?['unit'] as Map<String, dynamic>?;
    final priceType = json['price_type'] as Map<String, dynamic>?;

    final rawPrice = json['price'];
    double price = 0;
    if (rawPrice != null) {
      price = double.tryParse(rawPrice.toString()) ?? 0;
    }

    return CatalogItemModel(
      id: json['id'] as String,
      productId: product?['id'] as String? ?? json['id'] as String,
      title: product?['title'] as String? ?? '',
      brand: brand?['title'] as String?,
      photoUrl: product?['photo'] as String?,
      unit: unit?['title'] as String?,
      price: price,
      priceTypeName: priceType?['title'] as String?,
      activityName: null,
    );
  }
}
