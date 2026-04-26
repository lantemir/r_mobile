// Сущность User — чистая бизнес-модель
// Никаких импортов Flutter или Dio здесь нет намеренно
class User {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? email;
  final String userType; // TRADE_AGENT, SUPERVISOR и т.д.

  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.userType,
  });

  // Удобный геттер — полное имя
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }
}
