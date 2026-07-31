import '../domain/route_outlet.dart';

class RouteOutletContactModel extends RouteOutletContact {
  const RouteOutletContactModel({
    required super.id,
    required super.fullName,
    required super.phoneNumber,
    required super.isDecisionMaker,
  });

  factory RouteOutletContactModel.fromJson(Map<String, dynamic> json) {
    return RouteOutletContactModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      isDecisionMaker: json['is_decision_maker'] as bool? ?? false,
    );
  }
}

class RouteOutletModel extends RouteOutlet {
  const RouteOutletModel({
    required super.id,
    required super.title,
    super.address,
    super.displayTitle,
    super.latitude,
    super.longitude,
    required super.status,
    required super.contacts,
  });

  factory RouteOutletModel.fromJson(Map<String, dynamic> json) {
    // location — GeoJSON формат:
    // {"type": "Point", "coordinates": [longitude, latitude]}
    // Важно: в GeoJSON сначала longitude потом latitude!
    double? lat;
    double? lng;
    final location = json['location'] as Map<String, dynamic>?;
    if (location != null) {
      final coords = location['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num).toDouble(); // longitude первый
        lat = (coords[1] as num).toDouble(); // latitude второй
      }
    }

    // contacts — список вложенных объектов
    final contacts = (json['contacts'] as List? ?? [])
        .map((c) => RouteOutletContactModel.fromJson(c as Map<String, dynamic>))
        .toList();

    return RouteOutletModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      displayTitle: json['display_title'] as String?,
      address: json['address'] as String?,
      latitude: lat,
      longitude: lng,
      status: json['status'] as String? ?? 'PENDING',
      contacts: contacts,
    );
  }
}
