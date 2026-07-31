import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/route_day.dart';
import '../domain/route_info.dart';
import '../domain/route_outlet.dart';
import '../domain/route_repository.dart';
import 'route_day_model.dart';
import 'route_info_model.dart';
import 'route_outlet_model.dart';

class RouteRepositoryImpl implements RouteRepository {
  final ApiClient _client;

  RouteRepositoryImpl(this._client);

  @override
  Future<RouteInfo> getRouteInfo() async {
    try {
      // GET /api/v1/route/
      // Возвращает ОДИН объект (не список!)
      // Только для торгового агента — у него есть маршрут
      final response = await _client.dio.get('route/');
      return RouteInfoModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.parseError(e));
    }
  }

  @override
  Future<List<RouteDay>> getRouteDays() async {
    try {
      // GET /api/v1/route/days/
      // Возвращает список дней с ID торговых точек
      final response = await _client.dio.get('route/days/');
      return (response.data as List)
          .map((e) => RouteDayModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(ApiClient.parseError(e));
    }
  }

  @override
  Future<List<RouteOutlet>> getRouteOutlets() async {
    try {
      // GET /api/v1/route/outlets/
      // Возвращает полные данные всех точек маршрута
      final response = await _client.dio.get('route/outlets/');
      return (response.data as List)
          .map((e) => RouteOutletModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(ApiClient.parseError(e));
    }
  }
}
