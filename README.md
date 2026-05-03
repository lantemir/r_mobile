# r_mobile

# R Mobile — Flutter Client

Мобильное приложение для системы Remote Mobile Trade (RMT).  
Финальный проект курса Flutter — DataGroup Academy.

Приложение подключено к реальному Django REST API бэкенду RMT-WEB.

---

## Скриншоты 

| Авторизация | Главная | Задачи | Заказы | Аналитика |
|---|---|---|---|---|

## Стек технологий

| Слой | Технология | Назначение |
|---|---|---|
| UI | Flutter 3 + Material 3 | Кроссплатформенный UI |
| State | Riverpod 2 | Управление состоянием |
| Navigation | GoRouter | Навигация с редиректами |
| HTTP | Dio | Запросы к Django API |
| Storage | flutter_secure_storage | Хранение токена |
| Cache | Hive | Офлайн-кэш данных |
| Charts | fl_chart | Графики аналитики |
| Backend | Django REST Framework | API сервер |
| Auth | Custom TokenAuthentication | Bearer токен |

---

## Архитектура — Clean Architecture

Проект разделён на три слоя внутри каждой фичи:

lib/
├── main.dart
└── src/
├── app/
│   └── router/         # GoRouter — навигация и редиректы
├── core/
│   ├── network/        # Dio клиент + Bearer interceptor
│   └── storage/        # TokenStorage (flutter_secure_storage)
└── features/
├── auth/
│   ├── domain/     # User, AuthRepository (интерфейс)
│   ├── data/       # UserModel, AuthRepositoryImpl
│   └── presentation/ # LoginScreen, AuthProviders
├── home/
│   └── presentation/ # HomeScreen (дашборд)
├── tasks/
│   ├── domain/     # Task, TaskRepository
│   ├── data/       # TaskModel, TaskRepositoryImpl
│   └── presentation/ # TasksScreen, TasksNotifier
├── orders/
│   ├── domain/     # Order, OrderRepository
│   ├── data/       # OrderModel, OrderRepositoryImpl
│   └── presentation/ # OrdersScreen, OrdersNotifier
└── analytics/
└── presentation/ # AnalyticsScreen (fl_chart)


**Принцип:** domain слой не знает о Flutter и Django.  
Если сменить бэкенд — меняем только `data/`, экраны остаются нетронутыми.

---


## API эндпоинты

| Экран | Метод | Эндпоинт | Описание |
|---|---|---|---|
| Авторизация | POST | `/api/v1/accounts/login/` | Получить Bearer токен |
| Главная | GET | `/api/v1/accounts/users/me/` | Данные пользователя |
| Задачи | GET | `/api/v1/tasks/` | Список задач (cursor pagination) |
| Заказы | GET | `/api/v1/orders/` | Список заказов (cursor pagination) |
| Аналитика | — | из ordersProvider | Группировка по датам локально |

**Авторизация:** R использует кастомный `TokenAuthentication` с префиксом `Bearer`.  
Каждый запрос автоматически добавляет заголовок через Dio interceptor:

Authorization: Bearer <token>

---

## Ключевые решения

**Офлайн-режим** — при потере сети Hive возвращает кэшированные данные.  
Показывается оранжевый баннер "Офлайн — показаны кэшированные данные".

**Реактивная навигация** — GoRouter подписан на `authProvider`.  
При изменении `isLoggedIn` роутер автоматически перенаправляет без `Navigator.push()`.

**Аналитика без нового запроса** — данные заказов уже в памяти через `ordersProvider`.  
Группируем по дате прямо в Flutter — derived state.

**UUID вместо int** — Django использует UUID для id (`6b1850a1-...`).  
Все модели используют `String` для id.

---

## Запуск проекта

### Требования
- Flutter SDK 3.x
- Android эмулятор или реальное устройство
- Docker (для локального бэкенда)

### 1. Клонировать репозиторий
```bash
git clone <repo-url>
cd r_mobile
```

### 2. Установить зависимости
```bash
flutter pub get
```

### 3. Настроить URL бэкенда

Открыть `lib/src/core/network/api_constants.dart`:

```dart
// Android эмулятор
static const String baseUrl = 'http://10.0.2.2:8000/api/v1/';

// Реальное устройство (IP вашего компьютера)
static const String baseUrl = 'http://192.168.1.x:8000/api/v1/';

// Dev сервер
static const String baseUrl = 'https://rmt20-dev.raimbek.com/api/v1/';
```

### 4. Запустить бэкенд (локально)
```bash
cd rmt-web
docker compose -f compose/dev.yml up
```

### 5. Запустить приложение
```bash
flutter run
```

---

## Тесты

```bash
flutter test
```

Покрытие тестами:
- `User.fullName` — сборка полного имени
- `UserModel.fromJson` — парсинг JSON пользователя
- `Task` геттеры статусов — `isNew`, `isCompleted`, `isOverdue`
- `TaskModel.fromJson` — парсинг JSON задачи
- `Order` геттеры — `totalFormatted`, статусы
- `OrderModel.fromJson` — парсинг JSON заказа

---

## Функциональность

- Авторизация через Bearer токен
- Просмотр задач с пагинацией и офлайн-кэшем
- Просмотр заказов с фильтрами по статусу
- Аналитика: графики заказов по датам, суммы, распределение статусов
- Pull-to-refresh на всех экранах
- Офлайн-режим через Hive

---

## Автор

**Темирлан Шайкенов**  
DataGroup Academy — Flutter курс, 2026