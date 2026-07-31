// Данные для формы создания заказа
class OrderFormData {
  final String outletId;
  final String counterpartyId;
  final String contractId;
  final String priceTypeId;
  final String warehouseId;
  final String paymentTypeId;
  final String visitId;

  const OrderFormData({
    required this.outletId,
    required this.counterpartyId,
    required this.contractId,
    required this.priceTypeId,
    required this.warehouseId,
    required this.paymentTypeId,
    required this.visitId,
  });
}
