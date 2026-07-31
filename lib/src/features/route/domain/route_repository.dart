import 'route_day.dart';
import 'route_info.dart';
import 'route_outlet.dart';

abstract class RouteRepository {
  // GET /api/v1/route/
  // Данные текущего маршрута залогиненного агента
  Future<RouteInfo> getRouteInfo();

  // GET /api/v1/route/days/
  // Список дней маршрута с ID торговых точек
  Future<List<RouteDay>> getRouteDays();

  // GET /api/v1/route/outlets/
  // Полные данные всех торговых точек маршрута
  Future<List<RouteOutlet>> getRouteOutlets();
}
