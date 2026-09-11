class CreateOrderItemParams {
  final String productMatchId;
  final double quantity;
  final String? activityMatchId; // акция на позицию, если есть
  final String? activitySettingId; // конкретная механика акции, если есть

  const CreateOrderItemParams({
    required this.productMatchId,
    required this.quantity,
    this.activityMatchId,
    this.activitySettingId,
  });
}

class CreateOrderParams {
  final String outletId;
  final String counterpartyId;
  final String visitId;
  final DateTime deliveryDate;
  final String comment;
  final List<CreateOrderItemParams> items;
  // Склад, на котором реально есть остатки товаров из корзины.
  // Если null — репозиторий возьмёт первый доступный склад маршрута
  // (старое поведение, для случаев когда остатки не удалось определить).
  final String? warehouseId;

  const CreateOrderParams({
    required this.outletId,
    required this.counterpartyId,
    required this.visitId,
    required this.deliveryDate,
    required this.comment,
    required this.items,
    this.warehouseId,
  });
}
