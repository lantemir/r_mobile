import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/presentation/auth_providers.dart';
import '../domain/order_form.dart';

// ─────────────────────────────────────────
// Состояние загрузки справочников
// ─────────────────────────────────────────

class OrderFormState {
  final bool isLoadingRefs; // загружаются справочники
  final bool isCreating; // создаётся заказ
  final String? error;
  final bool isSuccess;
  final String? orderId;

  // Справочники
  final String? priceTypeId;
  final String? warehouseId;
  final String? paymentTypeId;
  final String? counterpartyId;
  final String? contractId;

  const OrderFormState({
    this.isLoadingRefs = false,
    this.isCreating = false,
    this.error,
    this.isSuccess = false,
    this.orderId,
    this.priceTypeId,
    this.warehouseId,
    this.paymentTypeId,
    this.counterpartyId,
    this.contractId,
  });

  bool get refsLoaded =>
      priceTypeId != null &&
      warehouseId != null &&
      paymentTypeId != null &&
      counterpartyId != null &&
      contractId != null;

  OrderFormState copyWith({
    bool? isLoadingRefs,
    bool? isCreating,
    String? error,
    bool? isSuccess,
    String? orderId,
    String? priceTypeId,
    String? warehouseId,
    String? paymentTypeId,
    String? counterpartyId,
    String? contractId,
    bool clearError = false,
  }) {
    return OrderFormState(
      isLoadingRefs: isLoadingRefs ?? this.isLoadingRefs,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      orderId: orderId ?? this.orderId,
      priceTypeId: priceTypeId ?? this.priceTypeId,
      warehouseId: warehouseId ?? this.warehouseId,
      paymentTypeId: paymentTypeId ?? this.paymentTypeId,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      contractId: contractId ?? this.contractId,
    );
  }
}

class CreateOrderNotifier extends StateNotifier<OrderFormState> {
  final Ref _ref;
  final String outletId;

  CreateOrderNotifier(this._ref, this.outletId)
    : super(const OrderFormState()) {
    loadRefs();
  }

  // Загружаем все справочники параллельно
  Future<void> loadRefs() async {
    state = state.copyWith(isLoadingRefs: true, clearError: true);

    try {
      final client = _ref.read(apiClientProvider);

      // Сначала получаем контрагентов для точки
      final counterpartiesResp = await client.dio.get(
        'route/counterparties/',
        queryParameters: {'outlet': outletId},
      );

      final counterparties = counterpartiesResp.data as List;
      print('=== COUNTERPARTIES: ${counterparties.length}');

      if (counterparties.isEmpty) {
        state = state.copyWith(
          isLoadingRefs: false,
          error: 'Нет контрагентов для этой точки',
        );
        return;
      }

      final counterparty = counterparties[0] as Map<String, dynamic>;
      final counterpartyId = counterparty['id'] as String;

      // Загружаем остальные справочники параллельно
      final results = await Future.wait([
        client.dio.get('route/price-types/'),
        client.dio.get('route/warehouses/'),
        client.dio.get('route/payment-types/'),
        // Договоры для конкретного контрагента
        client.dio.get(
          'route/contracts/',
          queryParameters: {'counterparty': counterpartyId},
        ),
      ]);

      final priceTypes = results[0].data as List;
      final warehouses = results[1].data as List;
      final paymentTypes = results[2].data as List;
      final contracts = results[3].data as List;

      print('=== PRICE TYPES: ${priceTypes.length}');
      print('=== WAREHOUSES: ${warehouses.length}');
      print('=== PAYMENT TYPES: ${paymentTypes.length}');
      print('=== CONTRACTS: ${contracts.length}');
      if (contracts.isNotEmpty) {
        print('=== FIRST CONTRACT: ${contracts[0]}');
      }

      if (contracts.isEmpty) {
        state = state.copyWith(
          isLoadingRefs: false,
          error: 'У контрагента нет договоров',
        );
        return;
      }

      state = state.copyWith(
        isLoadingRefs: false,
        priceTypeId: priceTypes.isNotEmpty
            ? (priceTypes[0] as Map)['id'] as String
            : null,
        warehouseId: warehouses.isNotEmpty
            ? (warehouses[0] as Map)['id'] as String
            : null,
        paymentTypeId: paymentTypes.isNotEmpty
            ? (paymentTypes[0] as Map)['id'] as String
            : null,
        counterpartyId: counterpartyId,
        contractId: (contracts[0] as Map)['id'] as String,
      );
    } on DioException catch (e) {
      print('=== REFS ERROR: ${e.response?.data}');
      print('=== REFS ERROR URL: ${e.requestOptions.uri}');
      state = state.copyWith(
        isLoadingRefs: false,
        error: 'Ошибка загрузки справочников: ${e.message}',
      );
    }
  }

  // Создать заказ
  Future<bool> createOrder({
    required String visitId,
    required DateTime deliveryDate,
    String? comment,
  }) async {
    if (!state.refsLoaded) return false;

    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final client = _ref.read(apiClientProvider);
      final id = const Uuid().v4();

      final response = await client.dio.post(
        'route/orders/',
        data: {
          'id': id,
          'outlet': outletId,
          'counterparty': state.counterpartyId,
          'contract': state.contractId,
          'price_type': state.priceTypeId,
          'warehouse': state.warehouseId,
          'payment_type': state.paymentTypeId,
          'visit': visitId,
          'order_type': 'REGULAR_ORDER',
          'delivery_date': deliveryDate.toIso8601String().substring(0, 10),
          'comment': comment ?? '',
          'by_phone': false,
          'created': DateTime.now().toUtc().toIso8601String(),
          'contents': [], // пустой заказ — товары добавим потом
        },
      );

      state = state.copyWith(
        isCreating: false,
        isSuccess: true,
        orderId: response.data['id'] as String?,
      );
      return true;
    } on DioException catch (e) {
      print('=== ORDER ERROR: ${e.response?.data}');
      final data = e.response?.data;
      String message = 'Ошибка создания заказа';
      if (data is Map) {
        message = data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      }
      state = state.copyWith(isCreating: false, error: message);
      return false;
    }
  }
}

// family — отдельный провайдер для каждой точки
final createOrderProvider = StateNotifierProvider.autoDispose
    .family<CreateOrderNotifier, OrderFormState, String>(
      (ref, outletId) => CreateOrderNotifier(ref, outletId),
    );
