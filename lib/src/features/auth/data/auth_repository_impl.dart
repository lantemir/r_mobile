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
