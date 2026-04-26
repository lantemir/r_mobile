import 'user.dart';

// Абстрактный класс — только описание, без реализации
// Слой data/ будет реализовывать этот контракт

abstract class AuthRepository {
  // Войти — отправляет username+password на Django
  // Возвращает токен при успехе
  Future<String> login({required String username, required String password});

  // Получить данные текущего пользователя
  // GET /api/v1/accounts/users/me/
  Future<User> getMe();

  // Выйти из аккаунта — удалить токен с устройства
  Future<void> logout();

  // Проверить — есть ли сохранённый токен
  // Используется при запуске приложения
  Future<bool> isLoggedIn();
}
