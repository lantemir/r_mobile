import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // Ключ под которым храним токен
  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  // Принимаем storage снаружи — так удобнее тестировать
  const TokenStorage(this._storage);

  // Получить токен (null если не залогинен)
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  // Сохранить токен после успешного логина
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  // Удалить токен при выходе из аккаунта
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // Проверка — есть ли токен вообще
  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }
}


// import 'package:shared_preferences/shared_preferences.dart';

// class TokenStorage {
//   static const _tokenKey = 'auth_token';

//   Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(_tokenKey);
//   }

//   Future<void> saveToken(String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_tokenKey, token);
//   }

//   Future<void> deleteToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_tokenKey);
//   }

//   Future<bool> hasToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString(_tokenKey);
//     return token != null && token.isNotEmpty;
//   }
// }

