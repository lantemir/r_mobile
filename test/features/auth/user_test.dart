import 'package:flutter_test/flutter_test.dart';
import 'package:r_mobile/src/features/auth/domain/user.dart';
import 'package:r_mobile/src/features/auth/data/user_model.dart';

void main() {
  // group объединяет связанные тесты
  group('User', () {
    test('fullName возвращает имя и фамилию', () {
      const user = User(
        id: 1,
        username: 'temir',
        firstName: 'Темир',
        lastName: 'Шайкенов',
        userType: 'TRADE_AGENT',
      );

      // expect(actual, matcher) — проверяем результат
      expect(user.fullName, 'Темир Шайкенов');
    });

    test('fullName возвращает username если имя пустое', () {
      const user = User(
        id: 1,
        username: 'temir',
        firstName: '',
        lastName: '',
        userType: 'TRADE_AGENT',
      );

      expect(user.fullName, 'temir');
    });

    test('fullName обрезает лишние пробелы', () {
      const user = User(
        id: 1,
        username: 'temir',
        firstName: 'Темир',
        lastName: '',
        userType: 'TRADE_AGENT',
      );

      // Не должно быть "Темир " с пробелом в конце
      expect(user.fullName, 'Темир');
    });
  });

  group('UserModel.fromJson', () {
    test('парсит полный JSON корректно', () {
      final json = {
        'id': 1,
        'username': 'temir',
        'first_name': 'Темир',
        'last_name': 'Шайкенов',
        'email': 'temir@mail.com',
        'user_type': 'TRADE_AGENT',
      };

      final user = UserModel.fromJson(json);

      expect(user.username, 'temir');
      expect(user.firstName, 'Темир');
      expect(user.lastName, 'Шайкенов');
      expect(user.email, 'temir@mail.com');
      expect(user.userType, 'TRADE_AGENT');
    });

    test('использует пустую строку если поля отсутствуют', () {
      // Минимальный JSON — только обязательные поля
      final json = {'id': 1, 'username': 'temir'};

      final user = UserModel.fromJson(json);

      expect(user.firstName, '');
      expect(user.lastName, '');
      expect(user.email, null);
      expect(user.userType, '');
    });
  });
}
