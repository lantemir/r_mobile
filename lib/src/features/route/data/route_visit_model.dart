import '../domain/route_visit.dart';

class RouteVisitModel extends RouteVisit {
  const RouteVisitModel({
    required super.id,
    required super.outletId,
    required super.started,
    super.ended,
    required super.status,
    super.comment,
    required super.created,
  });

  factory RouteVisitModel.fromJson(Map<String, dynamic> json) {
    return RouteVisitModel(
      id: json['id'] as String,
      outletId: json['outlet'] as String? ?? '',
      started: json['started'] as String? ?? '',
      ended: json['ended'] as String?,
      status: json['status'] as String? ?? 'VISITED',
      comment: json['comment'] as String?,
      created: json['created'] as String? ?? '',
    );
  }
}
