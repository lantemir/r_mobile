import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/token_storage.dart';
import 'api_constants.dart';

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient(this.tokenStorage) {
    // Базовые настройки всех запросов
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor — добавляет токен к каждому запросу
    // Аналог middleware в Django
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getToken();
          if (token != null) {
            // RMT использует стандартный DRF Token
            // Заголовок: Authorization: Token abc123...
            options.headers['Authorization'] = 'Token $token';
          }
          handler.next(options); // продолжить запрос
        },
        onError: (DioException error, handler) {
          // Здесь можно обработать 401 (токен устарел)
          handler.next(error);
        },
      ),
    );
  }

  // Статический метод — читает ошибку из ответа Django
  // Django DRF возвращает ошибки в формате:
  // {"non_field_errors": ["Неверный логин"]}
  // {"username": ["Пользователь не найден"]}
  static String parseError(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      if (data['non_field_errors'] is List) {
        return (data['non_field_errors'] as List).first.toString();
      }
      if (data['username'] is List) {
        return (data['username'] as List).first.toString();
      }
      if (data['detail'] != null) {
        return data['detail'].toString();
      }
    }

    // Сетевые ошибки
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Проверьте соединение.';
      case DioExceptionType.connectionError:
        return 'Нет подключения к серверу.';
      default:
        return 'Ошибка: ${e.message}';
    }
  }
}
