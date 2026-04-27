import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

// ─────────────────────────────────────────
// 1. Инфраструктурные провайдеры
// Создаём объекты один раз на всё приложение
// ─

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // Получаем tokenStorage из провайдера выше
  return ApiClient(ref.read(tokenStorageProvider));
});

final AuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(apiClientProvider));
});

// ─────────────────────────────────────────
// 2. Состояние авторизации
// Хранит все данные связанные с авторизацией
// ──

class AuthState {
  final bool isLoading; // идёт ли запрос прямо сейчас
  final String? error; // текст ошибки если есть
  final bool isLoggedIn; // залогинен ли пользователь
  final User? user; // данные пользователя

  const AuthState({
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
    this.user,
  });

  // Создаём новое состояние на основе текущего
  // В Dart объекты неизменяемые — меняем через copyWith
  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
    User? user,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
    );
  }
}

// ─────────────────────────────────────────
// 3. AuthNotifier — управляет состоянием
// Аналог ViewModel или Controller
// ─────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    // При создании сразу проверяем — есть ли токен
    // Это нужно чтобы не показывать логин если уже залогинен
    _checkAuth();
  }

  // Проверка при запуске приложения
  Future<void> _checkAuth() async {
    final loggedIn = await _repository.isLoggedIn();
    if (loggedIn) {
      try {
        final user = await _repository.getMe();
        state = state.copyWith(isLoggedIn: true, user: user);
      } catch (_) {
        // Токен есть но устарел — удаляем
        await _repository.logout();
        state = state.copyWith(isLoggedIn: false);
      }
    }
  }

  // Войти
  Future<bool> login(String username, String password) async {
    // Показываем лоадер, убираем старую ошибку
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.login(username: username, password: password);
      final user = await _repository.getMe();
      state = state.copyWith(isLoading: false, isLoggedIn: true, user: user);
      return true; //успех
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false; //ошибка
    }
  }

  // Выйти
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(); // сбрасываем всё состояние
  }
}

// Финальный провайдер — его используют экраны
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(AuthRepositoryProvider));
});
