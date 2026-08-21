class CatalogItem {
  final String id; // id product_match
  final String productId; // id самого продукта
  final String title; // название товара
  final String? brand; // бренд
  final String? photoUrl; // фото
  final String? unit; // единица измерения
  final double price; // цена
  final String? priceTypeName; // тип цены
  final String? activityName; // название акции если есть
  final String? activityMatchId; // для передачи в заказ
  final double? activityPrice; // акционная цена, если есть
  final double stock; // ← остаток на складе
  final double reserved; // ← зарезервировано

  const CatalogItem({
    required this.id,
    required this.productId,
    required this.title,
    this.brand,
    this.photoUrl,
    this.unit,
    required this.price,
    this.priceTypeName,
    this.activityName,
    this.activityMatchId,
    this.activityPrice,
    this.stock = 0,
    this.reserved = 0,
  });

  // Есть ли акция на товар
  bool get hasActivity => activityName != null;

  bool get inStock => stock > 0;
  double get available => stock - reserved; // доступно к заказу

  // Эффективная цена — акционная, если есть, иначе обычная
  double get effectivePrice => activityPrice ?? price;

  // Форматированная цена (с учётом акции)
  String get formattedPrice => '${effectivePrice.toStringAsFixed(2)} ₸';

  // Форматированная цена с единицей (с учётом акции)
  String get formattedPriceWithUnit {
    final unitStr = unit != null ? ' / $unit' : '';
    return '${effectivePrice.toStringAsFixed(2)} ₸$unitStr';
  }

  String get stockDisplay {
    if (stock <= 0) return 'Нет в наличии';
    if (available <= 0) return 'Зарезервировано';
    return '${available.toStringAsFixed(0)} ${unit ?? 'шт'}';
  }
}

// Товар в корзине — товар + количество
class CartItem {
  final CatalogItem item;
  final double quantity;

  const CartItem({required this.item, required this.quantity});

  // Сумма по позиции (с учётом акционной цены)
  double get total => item.effectivePrice * quantity;

  String get formattedTotal => '${total.toStringAsFixed(2)} ₸';

  CartItem copyWith({double? quantity}) {
    return CartItem(item: item, quantity: quantity ?? this.quantity);
  }
}
