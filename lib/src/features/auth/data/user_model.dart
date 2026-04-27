import '../domain/user.dart';

// Расширяет User — добавляет умение парсить JSON от Django
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.firstName,
    required super.lastName,
    super.email,
    required super.userType,
  });
  // Фабричный конструктор — принимает JSON от Django
  // GET /api/v1/accounts/users/me/ возвращает примерно:
  // {
  //   "id": 1,
  //   "username": "kilibayev",
  //   "first_name": "Ashirbek",
  //   "last_name": "Kilibayev",
  //   "email": "a@mail.com",
  //   "user_type": "TRADE_AGENT"
  // }
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      userType: json['user_type'] as String? ?? '',
    );
  }
}
