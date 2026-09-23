import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';
import 'otp_screen.dart';

// ConsumerStatefulWidget — StatefulWidget который умеет читать провайдеры

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Очищаем контроллеры когда экран уничтожается
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    // Код запрашивается только по логину — пароль/OTP здесь не нужен
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала введите логин (номер маршрута)')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).requestOtp(username);
    if (!mounted) return;

    if (success) {
      // Дальше код вводится уже на отдельном экране с 6 полями
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(username: username)),
      );
    }
    // Ошибку покажет общий блок authState.error ниже
  }

  Future<void> _submit() async {
    // Проверяем форму — если не валидна, стоп
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Вызываем login в AuthNotifier
    final succes = await ref
        .read(authProvider.notifier)
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim());

    // Если успех — переходим на главный экран
    if (succes && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся на состояние — экран перерисуется
    // когда isLoading или error изменятся
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Иконка приложения
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Заголовок
                  Text(
                    'R-Mobile',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Remote Trade',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Блок ошибки — показывается только если есть ошибка
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        authState.error!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Поле логина
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Введите логин"
                        : null,
                  ),
                  const SizedBox(height: 8),

                  // Кнопка запроса OTP-кода — для торговых агентов
                  // (у дашборд-пользователей обычный пароль, им кнопка не нужна,
                  // но лишним нажатием пароль не ломается — можно жать всем)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: authState.isOtpLoading ? null : _requestOtp,
                      child: authState.isOtpLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Получить код'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Поле пароля
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      // Кнопка показать/скрыть пароль
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Введите пароль'
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // Кнопка входа
                  FilledButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Показываем спиннер пока идёт запрос
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Войти',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Подсказка про OTP
                  Text(
                    'Торговые агенты: нажмите «Получить код» — его сообщит супервайзер',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
