import '../domain/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.firstName,
    required super.lastName,
    super.email,
    required super.userType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // id может отсутствовать — используем 0 по умолчанию
      id: json['id'] as int? ?? 0,
      // Django возвращает display_name если нет username
      username:
          json['username'] as String? ?? json['display_name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      // user_type тоже может отличаться
      userType: json['user_type'] as String? ?? '',
    );
  }
}
