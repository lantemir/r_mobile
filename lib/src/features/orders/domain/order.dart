class Order {
  final String id;
  final String? code; // номер заказа
  final String status;
  final String statusDisplay; // "Новый", "Отправлен" и т.д.
  final String orderType;
  final String orderTypeDisplay;
  final String? total; // сумма заказа
  final String? outletName; // название торговой точки
  final String? deliveryDate; // дата доставки
  final String? documentStatusDisplay; // статус документа
  final String created;
  final bool byPhone;

  const Order({
    required this.id,
    this.code,
    required this.status,
    required this.statusDisplay,
    required this.orderType,
    required this.orderTypeDisplay,
    this.total,
    this.outletName,
    this.deliveryDate,
    this.documentStatusDisplay,
    required this.created,
    required this.byPhone,
  });

  // Удобные геттеры для UI
  bool get isNew => status == 'NEW';
  bool get isSent => status == 'SENT';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isCancelled => status == 'CANCELLED';

  // Форматированная сумма
  String get totalFormatted {
    if (total == null) return '0.00 ₸';
    return '$total ₸';
  }
}
