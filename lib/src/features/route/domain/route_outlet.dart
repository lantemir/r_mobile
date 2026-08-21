class RouteOutletContact {
  final String id;
  final String fullName;
  final String phoneNumber;
  final bool isDecisionMaker;

  const RouteOutletContact({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.isDecisionMaker,
  });
}

class RouteOutlet {
  final String id;
  final String title;
  final String? address;
  final String? displayTitle;
  final double? latitude; // координаты для карты
  final double? longitude;
  final String status;
  final List<RouteOutletContact> contacts;
  final List<String> counterparties;

  const RouteOutlet({
    required this.id,
    required this.title,
    this.address,
    this.displayTitle,
    this.latitude,
    this.longitude,
    required this.status,
    required this.contacts,
    this.counterparties = const [],
  });

  // Основной контакт — тот кто принимает решения
  RouteOutletContact? get decisionMaker =>
      contacts.where((c) => c.isDecisionMaker).firstOrNull;

  // Есть ли координаты для отображения на карте
  bool get hasLocation => latitude != null && longitude != null;

  // Отображаемое название — берём displayTitle если есть
  String get name => displayTitle?.isNotEmpty == true ? displayTitle! : title;
}
