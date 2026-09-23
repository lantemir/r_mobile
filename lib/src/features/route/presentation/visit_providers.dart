import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:r_mobile/src/core/network/api_client.dart';

import '../../../core/network/api_constants.dart';
import '../../../features/auth/presentation/auth_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../data/route_visit_model.dart';
import '../domain/route_visit.dart';

// Состояние визита — от создания до завершения.
// ВАЖНО: завершение визита (isEnded/endedAt) сейчас чисто локальное —
// бэкенд route/visits/ умеет только создавать визит, обновлять (PATCH)
// пока нельзя, поэтому started/ended на сервере как были равны друг другу
// на старте визита, так и остаются. Реальная длительность в "Истории
// визитов" появится только когда на бэкенде добавят эндпоинт обновления.
class VisitState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? visitId; // id созданного визита
  final DateTime? startedAt; // локальное время начала — для таймера на экране
  final bool isEnded;
  final DateTime? endedAt; // локальное время завершения — для отображения

  const VisitState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.visitId,
    this.startedAt,
    this.isEnded = false,
    this.endedAt,
  });

  // Сколько идёт (или шёл) визит — считаем по локальным меткам времени
  Duration? get elapsed {
    if (startedAt == null) return null;
    return (endedAt ?? DateTime.now()).difference(startedAt!);
  }

  VisitState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? visitId,
    DateTime? startedAt,
    bool? isEnded,
    DateTime? endedAt,
    bool clearError = false,
  }) {
    return VisitState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      visitId: visitId ?? this.visitId,
      startedAt: startedAt ?? this.startedAt,
      isEnded: isEnded ?? this.isEnded,
      endedAt: endedAt ?? this.endedAt,
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
          'status': 'MERCHANDISING_ACCEPTED',
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
        startedAt: DateTime.now(),
      );
      return true;
    } on DioException catch (e) {
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

  // Завершить визит — ПОКА чисто локально: останавливает таймер на экране
  // и запоминает итоговую длительность в памяти приложения.
  // route/visits/ на бэкенде умеет только создавать визит (POST), обновлять
  // существующий (PATCH ended/status) пока нельзя — поэтому started/ended
  // на сервере остаются равны друг другу, как их отправил startVisit().
  // Как только на бэкенде появится эндпоинт обновления — здесь будет
  // реальный запрос, и длительность станет видна и в "Истории визитов".
  void endVisit() {
    if (state.visitId == null) return;
    state = state.copyWith(isEnded: true, endedAt: DateTime.now());
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
