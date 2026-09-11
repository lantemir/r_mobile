// Бонусный товар по механике N+M: купи buyQuantity основного товара —
// получи bonusQuantity этого товара бесплатно (кол-во считается на клиенте,
// цену бонусной позиции — 0 или иначе — всё равно пересчитает сервер).
class BonusOffer {
  final String productMatchId; // id бонусного товара в этой точке
  final String title;
  final int buyQuantity;
  final int bonusQuantity;
  final bool oneTimePurchase; // акция срабатывает только один раз за заказ
  final String activitySettingId; // ActivitySetting с setting_type = N_PLUS_M
  final String? warehouseId; // склад, на котором есть остатки бонусного товара

  const BonusOffer({
    required this.productMatchId,
    required this.title,
    required this.buyQuantity,
    required this.bonusQuantity,
    required this.oneTimePurchase,
    required this.activitySettingId,
    this.warehouseId,
  });
}

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
  final String? activitySettingId; // конкретная механика акции, для заказа
  final double? activityPrice; // акционная цена, если есть
  final double stock; // ← остаток на складе
  final double reserved; // ← зарезервировано
  final BonusOffer? bonus; // механика N+M на этот товар, если есть
  final bool isBonus; // true — это бесплатная позиция, добавленная за акцию
  final String? warehouseId; // склад, на котором числятся остатки этого товара

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
    this.activitySettingId,
    this.activityPrice,
    this.stock = 0,
    this.reserved = 0,
    this.bonus,
    this.isBonus = false,
    this.warehouseId,
  });

  // Есть ли акция на товар
  bool get hasActivity => activityName != null;

  bool get inStock => stock > 0;
  double get available => stock - reserved; // доступно к заказу

  // Эффективная цена — акционная, если есть, иначе обычная
  double get effectivePrice => activityPrice ?? price;

  // Форматированная цена (с учётом акции)
  String get formattedPrice =>
      isBonus ? 'бесплатно' : '${effectivePrice.toStringAsFixed(2)} ₸';

  // Форматированная цена с единицей (с учётом акции)
  String get formattedPriceWithUnit {
    if (isBonus) return 'бесплатно';
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
