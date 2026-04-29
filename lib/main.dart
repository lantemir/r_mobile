import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/app/router/app_router.dart';

void main() async {
  // Нужно вызвать до любого async кода
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем Hive — локальная БД для офлайн-кэша
  await Hive.initFlutter();

  runApp(
    // ProviderScope — корневой контейнер Riverpod
    // Все провайдеры живут внутри него
    const ProviderScope(child: RmtApp()),
  );
}

// ConsumerWidget — виджет который умеет читать провайдеры
class RmtApp extends ConsumerWidget {
  const RmtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем роутер из провайдера
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'RMT',
      debugShowCheckedModeBanner: false,

      // Тема — цвет как у оригинала RMT (тёмно-синий)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5276),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),

      routerConfig: router,
    );
  }
}
