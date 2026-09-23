import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';

const _otpLength = 6;
const _resendCooldownSeconds = 60;

// Экран ввода одноразового кода (OTP) для торговых агентов — открывается
// после нажатия "Получить код" на LoginScreen. Сам код в приложение не
// приходит (не SMS-рассылка) — его агенту сообщает супервайзер, поэтому
// автозаполнение (AutofillHints.oneTimeCode) здесь не имеет смысла.
class OtpScreen extends ConsumerStatefulWidget {
  final String username;

  const OtpScreen({super.key, required this.username});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  Timer? _cooldownTimer;
  int _secondsLeft = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _secondsLeft = _resendCooldownSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_code.length == _otpLength) {
      FocusScope.of(context).unfocus();
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_code.length != _otpLength) return;

    final success = await ref
        .read(authProvider.notifier)
        .login(widget.username, _code);
    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      // Даём ввести код заново — ошибку покажет authState.error ниже
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    }
  }

  Future<void> _resend() async {
    final success = await ref
        .read(authProvider.notifier)
        .requestOtp(widget.username);
    if (!mounted) return;

    if (success) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код запрошен повторно')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.password_rounded,
                  size: 52,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Введите код',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Код для «${widget.username}» узнайте у супервайзера',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

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

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _otpLength,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: i < _otpLength - 1 ? 8 : 0),
                      child: _OtpDigitBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        autofocus: i == 0,
                        onChanged: (v) => _onDigitChanged(i, v),
                        onBackspaceEmpty: () {
                          if (i > 0) {
                            _focusNodes[i - 1].requestFocus();
                            _controllers[i - 1].clear();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: authState.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                          'Подтвердить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: _secondsLeft > 0 || authState.isOtpLoading
                      ? null
                      : _resend,
                  child: authState.isOtpLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _secondsLeft > 0
                              ? 'Отправить код повторно через $_secondsLeft с'
                              : 'Отправить код повторно',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspaceEmpty;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
    required this.onBackspaceEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 52,
      // Focus-обёртка ловит Backspace на уже пустом поле — сам TextField
      // такое событие не обрабатывает (стирать нечего), оно всплывает сюда
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspaceEmpty();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
