import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:r_mobile/src/core/network/api_client.dart';

import '../../../core/network/api_constants.dart';
import '../../../features/auth/presentation/auth_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../data/route_visit_model.dart';
import '../domain/route_visit.dart';

// Состояние создания визита
class VisitState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? visitId; // id созданного визита

  const VisitState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.visitId,
  });

  VisitState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? visitId,
    bool clearError = false,
  }) {
    return VisitState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      visitId: visitId ?? this.visitId,
    );
  }
}

class VisitNotifier extends StateNotifier<VisitState> {
  final Ref _ref;

  VisitNotifier(this._ref) : super(const VisitState());

  Future<bool> startVisit({
    required String outletId,
    required int plannedOrder,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final client = _ref.read(apiClientProvider);
      final now = DateTime.now().toUtc().toIso8601String();

      // Генерируем UUID для id
      final id = const Uuid().v4();

      // Получаем геолокацию
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position? position;
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      final response = await client.dio.post(
        ApiConstants.routeVisits,
        data: {
          'id': id,
          'outlet': outletId,
          'started': now,
          'ended': now, // пока равно started
          'status': 'VISITED',
          'created': now,
          'planned_order': plannedOrder,
          // GeoJSON формат — Django ожидает именно так
          if (position != null)
            'location': {
              'type': 'Point',
              'coordinates': [
                position.longitude, // longitude первый!
                position.latitude,
              ],
            },
        },
      );

      final visitId = response.data['id'] as String;
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        visitId: visitId,
      );
      return true;
    } on DioException catch (e) {
      print('=== VISIT ERROR: ${e.response?.statusCode}');
      print('=== VISIT ERROR DATA: ${e.response?.data}');

      final data = e.response?.data;
      String message = 'Ошибка создания визита';
      if (data is Map) {
        final errors = data.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        message = errors;
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const VisitState();
  }
}

class OutletVisitsState {
  final bool isLoading;
  final String? error;
  final List<RouteVisit> visits;

  const OutletVisitsState({
    this.isLoading = false,
    this.error,
    this.visits = const [],
  });

  OutletVisitsState copyWith({
    bool? isLoading,
    String? error,
    List<RouteVisit>? visits,
  }) {
    return OutletVisitsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      visits: visits ?? this.visits,
    );
  }
}

class OutletVisitsNotifier extends StateNotifier<OutletVisitsState> {
  final Ref _ref;
  final String outletId;

  OutletVisitsNotifier(this._ref, this.outletId)
    : super(const OutletVisitsState()) {
    loadVisits();
  }

  Future<void> loadVisits() async {
    state = state.copyWith(isLoading: true);
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.dio.get(
        ApiConstants.routeVisits,
        queryParameters: {'outlet': outletId},
      );

      final visits = (response.data as List)
          .map((e) => RouteVisitModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(isLoading: false, visits: visits);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: ApiClient.parseError(e));
    }
  }
}

// autoDispose + family — создаётся отдельно для каждой точки
final outletVisitsProvider = StateNotifierProvider.autoDispose
    .family<OutletVisitsNotifier, OutletVisitsState, String>(
      (ref, outletId) => OutletVisitsNotifier(ref, outletId),
    );

final visitProvider =
    StateNotifierProvider.autoDispose<VisitNotifier, VisitState>((ref) {
      return VisitNotifier(ref);
    });
