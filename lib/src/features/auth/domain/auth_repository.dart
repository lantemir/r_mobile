import 'user.dart';

// Абстрактный класс — только описание, без реализации
// Слой data/ будет реализовывать этот контракт

abstract class AuthRepository {
  // Резолвит бренд по короткому домену из логина (например "raimbek" из
  // "451@raimbek.kz") через общий на все бренды сервис rmt-api-ce и
  // переключает ApiClient на бэкенд этого бренда. Если мультитенантность
  // выключена (ApiConstants.tenantApiBaseUrl пуст) — ничего не делает.
  // Бросает исключение, если бренд не найден или отключён.
  Future<void> resolveTenant(String domain);

  // Запросить одноразовый код (OTP) для торгового агента
  // POST /api/v1/accounts/login/code/ — Django генерирует код и кладёт в кэш
  // на 5 минут; сам код агенту сообщает супервайзер (видит его в админке)
  Future<void> requestOtp({required String username});

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
