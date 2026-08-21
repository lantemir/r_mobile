import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_item.dart';
import 'catalog_providers.dart';

// Создание заказа теперь идёт через orders-фичу (Clean Architecture)
import '../../orders/domain/create_order_params.dart';
import '../../orders/presentation/order_providers.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  final String outletId;
  final String outletName;
  final String visitId;
  final String counterpartyId;

  const CatalogScreen({
    super.key,
    required this.outletId,
    required this.outletName,
    required this.visitId,
    required this.counterpartyId,
  });

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogProvider(widget.outletId));
    final cartState = ref.watch(cartProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'КАТАЛОГ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // Кнопка корзины с счётчиком
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.white,
                ),
                onPressed: cartState.itemsCount > 0
                    ? () => _showCart(context)
                    : null,
              ),
              if (cartState.itemsCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartState.itemsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        // Поиск внизу AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) =>
                  ref.read(catalogProvider(widget.outletId).notifier).search(q),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white60,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white60,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(catalogProvider(widget.outletId).notifier)
                              .search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ),

      body: _buildBody(catalogState, cartState),

      // Нижняя панель с итогом корзины
      bottomNavigationBar: cartState.itemsCount > 0
          ? _CartSummaryBar(
              cartState: cartState,
              onOrder: () => _showCart(context),
            )
          : null,
    );
  }

  Widget _buildBody(CatalogState catalog, CartState cart) {
    if (catalog.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalog.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(catalog.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(catalogProvider(widget.outletId).notifier)
                  .loadItems(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (catalog.filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Товары не найдены'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: catalog.filtered.length,
      itemBuilder: (context, index) {
        final item = catalog.filtered[index];
        final quantity = cart.quantityOf(item.id);
        return _CatalogItemCard(
          item: item,
          quantity: quantity,
          onIncrement: () => ref.read(cartProvider.notifier).increment(item),
          onDecrement: () => ref.read(cartProvider.notifier).decrement(item),
          onSetQuantity: (q) =>
              ref.read(cartProvider.notifier).setQuantity(item, q),
        );
      },
    );
  }

  // Показать корзину
  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CartBottomSheet(
        outletId: widget.outletId,
        outletName: widget.outletName,
        visitId: widget.visitId,
        counterpartyId: widget.counterpartyId,
      ),
    );
  }
}

// ──────────────────────────────────────────
// Карточка товара
// ──────────────────────────────────────────

class _CatalogItemCard extends StatelessWidget {
  final CatalogItem item;
  final double quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<double> onSetQuantity;

  const _CatalogItemCard({
    required this.item,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSetQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inCart = quantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: inCart ? colorScheme.primary : colorScheme.outlineVariant,
          width: inCart ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото товара
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_outlined,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        item.title.isNotEmpty
                            ? item.title.substring(0, 2).toUpperCase()
                            : '??',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Информация о товаре
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Акция бейдж
                  if (item.hasActivity) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.activityName!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Название
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Бренд
                  if (item.brand != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.brand!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (item.brand != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.brand!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        item.inStock
                            ? Icons.inventory_2_outlined
                            : Icons.remove_circle_outline_rounded,
                        size: 11,
                        color: item.inStock ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.stockDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.inStock ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Цена и кнопки
                  Row(
                    children: [
                      // Цена
                      Expanded(
                        child: Text(
                          item.formattedPriceWithUnit,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),

                      // Кнопки количества
                      if (quantity > 0) ...[
                        // Уменьшить
                        _QuantityButton(
                          icon: Icons.remove_rounded,
                          onTap: onDecrement,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        // Количество — нажать для ввода вручную
                        GestureDetector(
                          onTap: () => _showQuantityInput(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quantity % 1 == 0
                                  ? quantity.toInt().toString()
                                  : quantity.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Увеличить
                        _QuantityButton(
                          icon: Icons.add_rounded,
                          onTap: onIncrement,
                          color: colorScheme.primary,
                        ),
                      ] else ...[
                        // Кнопка добавить
                        FilledButton.icon(
                          onPressed: onIncrement,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('В заказ'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог ввода количества вручную
  void _showQuantityInput(BuildContext context) {
    final ctrl = TextEditingController(
      text: quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toString(),
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Количество',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(ctrl.text) ?? 0;
              onSetQuantity(q);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Кнопка количества
// ──────────────────────────────────────────

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Нижняя панель корзины
// ──────────────────────────────────────────

class _CartSummaryBar extends StatelessWidget {
  final CartState cartState;
  final VoidCallback onOrder;

  const _CartSummaryBar({required this.cartState, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cartState.itemsCount} позиций',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    cartState.formattedTotal,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onOrder,
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: const Text('Оформить'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Корзина — Bottom Sheet
// ──────────────────────────────────────────

class _CartBottomSheet extends ConsumerWidget {
  final String outletId;
  final String outletName;
  final String visitId;
  final String counterpartyId;

  const _CartBottomSheet({
    required this.outletId,
    required this.outletName,
    required this.visitId,
    required this.counterpartyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Ручка
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Заголовок
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Корзина',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clear();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Очистить',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Список товаров в корзине
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: cartState.cartItems.length,
              itemBuilder: (_, index) {
                final cartItem = cartState.cartItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Название
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.item.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${cartItem.item.formattedPrice} × ${cartItem.quantity % 1 == 0 ? cartItem.quantity.toInt() : cartItem.quantity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Сумма
                      Text(
                        cartItem.formattedTotal,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      // Удалить
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .setQuantity(cartItem.item, 0),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Итог и кнопка оформить
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого (${cartState.itemsCount} поз.):',
                      style: const TextStyle(fontSize: 15),
                    ),
                    Text(
                      cartState.formattedTotal,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Открываем экран создания заказа
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _OrderConfirmScreen(
                            outletId: outletId,
                            outletName: outletName,
                            visitId: visitId,
                            counterpartyId: counterpartyId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: const Text(
                      'Оформить заказ',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Экран подтверждения заказа
// ──────────────────────────────────────────

class _OrderConfirmScreen extends ConsumerStatefulWidget {
  final String outletId;
  final String outletName;
  final String visitId;
  final String counterpartyId;

  const _OrderConfirmScreen({
    required this.outletId,
    required this.outletName,
    required this.visitId,
    required this.counterpartyId,
  });

  @override
  ConsumerState<_OrderConfirmScreen> createState() =>
      _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends ConsumerState<_OrderConfirmScreen> {
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    final cartState = ref.read(cartProvider);

    final params = CreateOrderParams(
      outletId: widget.outletId,
      counterpartyId: widget.counterpartyId,
      visitId: widget.visitId,
      deliveryDate: _deliveryDate,
      comment: _commentCtrl.text,
      items: cartState.cartItems
          .map(
            (ci) => CreateOrderItemParams(
              productMatchId: ci.item.id,
              quantity: ci.quantity,
              activityMatchId: ci.item.activityMatchId,
            ),
          )
          .toList(),
    );

    final success = await ref.read(createOrderProvider.notifier).create(params);

    if (!mounted) return;

    if (success) {
      ref.read(cartProvider.notifier).clear();
      final order = ref.read(createOrderProvider).createdOrder;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Заказ создан! ${order?.code ?? ''}'),
          backgroundColor: Colors.green,
        ),
      );
      // Возвращаемся на экран точки
      Navigator.of(context)
        ..pop()
        ..pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final createState = ref.watch(createOrderProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Оформление заказа',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Торговая точка
            _SummaryCard(
              icon: Icons.storefront_rounded,
              label: 'Торговая точка',
              value: widget.outletName,
            ),
            const SizedBox(height: 12),

            // Товары
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Товары (${cartState.itemsCount} поз.)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...cartState.cartItems.map(
                    (ci) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ci.item.title,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${ci.quantity % 1 == 0 ? ci.quantity.toInt() : ci.quantity} × ${ci.item.formattedPrice}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ci.formattedTotal,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Итого:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          cartState.formattedTotal,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Дата доставки
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _deliveryDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() => _deliveryDate = date);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: _SummaryCard(
                icon: Icons.calendar_today_rounded,
                label: 'Дата доставки',
                value:
                    '${_deliveryDate.day.toString().padLeft(2, '0')}.${_deliveryDate.month.toString().padLeft(2, '0')}.${_deliveryDate.year}',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Комментарий
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Комментарий к заказу...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),

            if (createState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  createState.error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Кнопка создать заказ
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: createState.isCreating ? null : _createOrder,
                icon: createState.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  createState.isCreating ? 'Создаём...' : 'Подтвердить заказ',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
