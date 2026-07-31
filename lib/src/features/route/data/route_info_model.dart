import '../domain/route_info.dart';

class RouteInfoModel extends RouteInfo {
  const RouteInfoModel({
    required super.id,
    required super.number,
    required super.title,
    required super.duration,
    required super.currentWeek,
    required super.canEditOutletLocations,
    required super.canCreateOrderInvoice,
  });

  factory RouteInfoModel.fromJson(Map<String, dynamic> json) {
    return RouteInfoModel(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      duration: json['duration'] as String? ?? 'ONE_WEEK',
      // current_week — какая сейчас неделя (0 или 1)
      // нужно для двухнедельных маршрутов
      currentWeek: json['current_week'] as int? ?? 0,
      canEditOutletLocations:
          json['can_edit_outlet_locations'] as bool? ?? false,
      canCreateOrderInvoice: json['can_create_order_invoice'] as bool? ?? false,
    );
  }
}
