import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<void> resolveTenant(String domain) async {
    // Мультитенантность выключена (локальная сборка против одного бэкенда,
    // TENANT_API_URL не задан в env/*.json) — работаем как раньше
    if (ApiConstants.tenantApiBaseUrl.isEmpty) return;

    try {
      // Отдельный Dio на этот один запрос — до резолва мы ещё не знаем
      // baseUrl основного _client, конфигурировать там нечего
      final tenantDio = Dio(
        BaseOptions(baseUrl: ApiConstants.tenantApiBaseUrl),
      );

      final response = await tenantDio.get(
        ApiConstants.tenantSettings,
        queryParameters: {'domain': domain},
      );

      final data = response.data as Map<String, dynamic>;
      final serviceUrl = data['serviceEndpointURL'] as String?;
      final isDisabled = data['isDisabled'] as bool? ?? false;

      if (serviceUrl == null || serviceUrl.isEmpty) {
        throw Exception('Организация «$domain» не найдена');
      }
      if (isDisabled) {
        throw Exception('Организация «$domain» отключена');
      }

      // serviceEndpointURL — корень бэкенда (например
      // "https://raimbek-rmt.velait.kz/"), API как и везде под /api/v1/
      final normalizedRoot = serviceUrl.endsWith('/')
          ? serviceUrl
          : '$serviceUrl/';
      _client.setBaseUrl('${normalizedRoot}api/v1/');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Организация «$domain» не найдена');
      }
      throw Exception('Не удалось определить сервер организации');
    }
  }

  @override
  Future<void> requestOtp({required String username}) async {
    try {
      // POST /api/v1/accounts/login/code/
      // Body: {"username": "..."} — ответ 204, тела нет
      await _client.dio.post(
        ApiConstants.loginCode,
        data: {'username': username},
      );
    } on DioException catch (e) {
      throw Exception(ApiClient.parseError(e));
    }
  }

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      // POST /api/v1/accounts/login/
      // Body: {"username": "...", "password": "..."}
      final response = await _client.dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      );

      // Django возвращает {"token": "abc123..."}
      final token = response.data['token'] as String;

      // Сохраняем токен в secure storage
      await _client.tokenStorage.saveToken(token);

      return token;
    } on DioException catch (e) {
      // Парсим ошибку из Django и бросаем понятное сообщение
      throw Exception(ApiClient.parseError(e));
    }
  }

  @override
  Future<User> getMe() async {
    try {
      // GET /api/v1/accounts/users/me/
      // Токен уже добавится автоматически через interceptor
      final response = await _client.dio.get(ApiConstants.me);

      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(ApiClient.parseError(e));
    }
  }

  @override
  Future<void> logout() async {
    // Просто удаляем токен с устройства
    // Следующий запрос уже не будет иметь Authorization заголовок
    await _client.tokenStorage.deleteToken();
  }

  @override
  Future<bool> isLoggedIn() {
    // Проверяем — есть ли токен в storage
    // Вызывается при каждом запуске приложения
    return _client.tokenStorage.hasToken();
  }
}
