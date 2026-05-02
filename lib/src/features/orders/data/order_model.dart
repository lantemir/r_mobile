import '../domain/order.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    super.code,
    required super.status,
    required super.statusDisplay,
    required super.orderType,
    required super.orderTypeDisplay,
    super.total,
    super.outletName,
    super.deliveryDate,
    super.documentStatusDisplay,
    required super.created,
    required super.byPhone,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final outlet = json['outlet'] as Map<String, dynamic>?;

    return OrderModel(
      id: json['id'] as String,
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'NEW',
      // status_display — на русском: "Новый", "Отправлен"
      statusDisplay: json['status_display'] as String? ?? '',
      orderType: json['order_type'] as String? ?? '',
      orderTypeDisplay: json['order_type_display'] as String? ?? '',
      // total приходит как число — конвертируем в строку
      total: json['total']?.toString(),
      // outlet — вложенный объект {"id": "...", "title": "Магазин"}
      outletName: outlet?['title'] as String?,
      deliveryDate: json['delivery_date'] as String?,
      documentStatusDisplay: json['document_status_display'] as String?,
      created: json['created'] as String? ?? '',
      byPhone: json['by_phone'] as bool? ?? false,
    );
  }
}
