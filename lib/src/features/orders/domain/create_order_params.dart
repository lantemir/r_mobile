class CreateOrderItemParams {
  final String productMatchId;
  final double quantity;
  final String? activityMatchId; // акция на позицию, если есть

  const CreateOrderItemParams({
    required this.productMatchId,
    required this.quantity,
    this.activityMatchId,
  });
}

class CreateOrderParams {
  final String outletId;
  final String counterpartyId;
  final String visitId;
  final DateTime deliveryDate;
  final String comment;
  final List<CreateOrderItemParams> items;

  const CreateOrderParams({
    required this.outletId,
    required this.counterpartyId,
    required this.visitId,
    required this.deliveryDate,
    required this.comment,
    required this.items,
  });
}
