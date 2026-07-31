import '../domain/route_day.dart';

class RouteDayModel extends RouteDay {
  const RouteDayModel({
    required super.id,
    required super.routeId,
    required super.day,
    required super.dayDisplay,
    required super.outletIds,
  });

  factory RouteDayModel.fromJson(Map<String, dynamic> json) {
    // outlets — список UUID строк
    // ["uuid1", "uuid2", "uuid3"]
    final outletIds = (json['outlets'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return RouteDayModel(
      id: json['id'] as String,
      routeId: json['route'] as String? ?? '',
      day: json['day'] as int? ?? 0,
      dayDisplay: json['day_display'] as String? ?? '',
      outletIds: outletIds,
    );
  }
}
