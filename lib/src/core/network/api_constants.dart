// Все адреса API в одном месте
class ApiConstants {
  // Базовый URL — меняем в зависимости от окружения
  // Android эмулятор: 10.0.2.2 = localhost компьютера
  // Реальный телефон: IP моего компьютера (например 192.168.1.5)
  // Dev сервер: https://...com

  //static const String baseUrl = 'http://10.0.2.2:8000/api/v1/';

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1/',
  );

  // Auth — из accounts/urls.py
  static const String login = 'accounts/login/';
  static const String me = 'accounts/users/me/';

  // Остальные модули — добавим по мере разработки

  static const String tasks = 'tasks/';
  static const String orders = 'orders/';
  static const String visits = 'visits/';
  static const String analytics = 'analytics/';
}
