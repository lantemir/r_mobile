# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter client for RMT (Remote Mobile Trade) — a field-sales / merchandising app that talks to a Django REST
Framework backend (`rmt-web`). It is a course project, so code favors clarity and explicit Russian comments
explaining Flutter/Dart concepts over idiomatic terseness — match that style when editing existing files.

## Commands

```bash
flutter pub get                                          # install dependencies

# Run against a specific backend — baseUrl is injected via --dart-define, not hardcoded.
flutter run --dart-define-from-file=env/local.json        # local Docker backend (10.0.2.2 = Android emulator's localhost)
flutter run --dart-define-from-file=env/dev.json          # shared dev server (rmt20-dev.raimbek.com)
flutter run --dart-define-from-file=env/prod.json         # production

flutter test                                               # run all tests
flutter test test/features/auth/user_test.dart             # run a single test file
flutter analyze                                             # static analysis (flutter_lints)
```

VS Code launch configs for the three environments above are already defined in `.vscode/launch.json`.

There is no `flutter build` / CI script checked into the repo beyond the standard Flutter tooling.

Note: `test/widget_test.dart` is unmodified Flutter boilerplate that references a `MyApp`/counter widget that
no longer exists (the real root widget is `RmtApp` in `lib/main.dart`) — it currently fails and is not
representative of the app.

## Architecture

Clean Architecture, one folder per feature under `lib/src/features/<feature>/`, each split into three layers:

- `domain/` — plain Dart entities and abstract repository interfaces. No Flutter or Dio imports here.
- `data/` — `*Model` classes (`fromJson`/API mapping) and `*RepositoryImpl` classes implementing the domain
  interface, talking to `ApiClient` and/or Hive.
- `presentation/` — screens (`*_screen.dart`) and Riverpod state (`*_providers.dart`, typically a
  `StateNotifier<SomeState>` + a `StateNotifierProvider`).

The rule of thumb: if the backend changed, only `data/` should need edits; domain and presentation stay put.

Current features: `auth`, `home`, `tasks`, `orders`, `route`, `catalog`, `analytics`, `sync`.

`route` is the largest/most involved feature — it models a rep's route (`route_day`, `route_visit`,
`route_outlet`, `route_info`) and drives order creation from an outlet visit (`create_order_screen.dart`,
`create_order_providers.dart`, `order_form.dart`). `orders/domain/create_order_params.dart` is the params
object passed from that flow into `OrderRepository.createOrder`.

### Cross-cutting core (`lib/src/core/`)

- `network/api_client.dart` — single `Dio` instance. An interceptor reads the bearer token from
  `TokenStorage` and attaches `Authorization: Bearer <token>` to every request. `ApiClient.parseError`
  centralizes turning DRF error payloads (`non_field_errors`, `username`, `detail`) into user-facing strings —
  reuse it instead of re-parsing `DioException` in new repositories.
- `network/api_constants.dart` — all endpoint paths in one place; `baseUrl` comes from
  `String.fromEnvironment('BASE_URL', ...)`, i.e. from the `--dart-define-from-file` env json, not from code.
- `storage/token_storage.dart` — wraps `flutter_secure_storage` for the auth token.

### Routing

`lib/src/app/router/app_router.dart` uses GoRouter with a `redirect` callback that watches `authProvider`
(Riverpod) directly — login state changes cause automatic redirects with no manual `Navigator` calls. New
top-level screens are added as flat `GoRoute`s here (routing is not nested/shell-based yet).

### State management pattern (Riverpod 2, StateNotifier-based)

Every feature's `*_providers.dart` file follows the same shape:
1. A `Provider<XRepository>` that builds the `XRepositoryImpl` from `apiClientProvider`.
2. An immutable `XState` with a `copyWith` (note the `bool clearError = false` / `clearCursor = false`
   flag pattern used to explicitly null out a field, since `copyWith(error: null)` can't distinguish
   "leave as-is" from "clear").
3. A `StateNotifier<XState>` that calls the repository and exposes imperative methods (`loadX`, `loadMore`,
   `create`), catching `DioException` separately from generic `Exception` to produce different error messages.
4. A `StateNotifierProvider` wiring the two together.

No `AsyncNotifier`/`riverpod_generator` codegen is used anywhere — providers are hand-written, so follow the
existing manual style rather than introducing `@riverpod` annotations.

### Offline caching

Cursor-paginated list endpoints (tasks, orders) cache their **first page only** into a per-feature Hive box
(opened lazily, e.g. `orders_cache`) on successful fetch. On a `DioException` (no network), the repository
falls back to reading that cache and returns it as if it were a live response — callers don't need separate
offline-handling logic. The `sync` feature (`sync_screen.dart`) is a manual "receive/send" UI that just
re-triggers `loadTasks()`/`loadOrders()` in sequence; it has no real background sync or outbox for offline
writes yet — writes (e.g. `createOrder`) are online-only.

### Discounts & promotions (`activities`)

Backend models three independent discount mechanisms on `Activity` (`rmt-web/apps/activities/models.py`);
mobile currently implements two of them:

- **BUY price override** (`ActivityProduct.product_type == BUY`) — read in `catalog_repository_impl.dart`,
  shown as `CatalogItem.effectivePrice`.
- **N+M bonus item** (`ActivitySetting.setting_type == N_PLUS_M` + paired `ActivityProduct.product_type ==
  BONUS`) — implemented client-side, see below.
- **Cascade discount** (`ActivityCascadeDiscount`) — not implemented. Backend exposes
  `GET route/cascade-discount/?activity_setting=<id>`; nothing on mobile calls it yet.

**Price is never sent to the server.** `createOrder()` only sends `product_match` + `activity_match` +
`activity_setting` per line; the backend always recomputes the authoritative price in
`BaseOrderRouteInputMixin.get_final_price()` (`rmt-web/apps/orders/serializers.py`). `CatalogItem.effectivePrice`
is a preview for the UI, not a commitment — don't build logic that assumes it's final.

**N+M bonus items are synthesized in the cart, not the catalog.** `catalog_repository_impl.dart` builds
`CatalogItem.bonus` (a `BonusOffer`: bonus product's match id, `buyQuantity`/`bonusQuantity`/`oneTimePurchase`,
and the `N_PLUS_M` `ActivitySetting.id`) from the same `route/activity-match-products/` response already
fetched for BUY pricing — no extra request needed. `CartNotifier._syncBonus()` (`catalog_providers.dart`)
recomputes the bonus line every time the triggering item's quantity changes
(`earned = (quantity ~/ buyQuantity) * bonusQuantity`, capped to one trigger if `oneTimePurchase`), storing it
under its own cart key (`bonus:<triggerItemId>:<bonusProductMatchId>`) so it never collides with a normal cart
entry. Bonus `CartItem`s have `CatalogItem.isBonus == true`, price `0`, and are not user-removable in the cart
UI — they're derived state, not independent line items.

**Expired/future activities are filtered client-side.** `route/activity-matches/` already includes
`started`/`ended` and each `ActivitySetting.is_active`; `catalog_repository_impl.dart` drops any activity
match outside `[started, ended]` (1-day grace since `ended` is a date, not a timestamp) before building any
price/bonus maps, so an expired promo just doesn't appear instead of being computed and hidden in the UI.

**`activity_setting` is sent alongside `activity_match`** on order contents
(`CreateOrderItemParams.activitySettingId`), resolved per `activity_match` by preferring the `ActivitySetting`
with `is_active == true`, else the first one. This doesn't change pricing (the server only needs
`activity_match` for that) but records which specific mechanic produced the line — matters once an activity
has more than one setting.

### Order creation: warehouse selection

Found while testing the above: `createOrder()` used to always POST `warehouses[0]` from `route/warehouses/`,
regardless of where the cart's products actually have stock — this fails server-side inventory validation
whenever an org has more than one warehouse. `CatalogItem.warehouseId` (sourced from `route/inventories/`'s
`warehouse` field) is threaded through to `CreateOrderParams.warehouseId`; `catalog_screen.dart` resolves it
from the cart before submitting and blocks client-side — instead of surfacing the backend's opaque
`non_field_errors` message — if cart items span more than one warehouse.

### IDs

Backend uses UUIDs (not ints) for most domain records — model IDs are `String`, except `User.id` which is
still an `int` from a different endpoint (`accounts/users/me/`). Don't assume all IDs are the same type
across features.
