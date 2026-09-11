import 'package:flutter_test/flutter_test.dart';
import 'package:r_mobile/src/features/catalog/domain/catalog_item.dart';
import 'package:r_mobile/src/features/catalog/presentation/catalog_providers.dart';

void main() {
  // Товар с механикой N+M: купи 6 — получи 2 бесплатно
  CatalogItem buyItem({double price = 100, bool oneTimePurchase = false}) {
    return CatalogItem(
      id: 'buy-1',
      productId: 'buy-1',
      title: 'Товар с акцией',
      price: price,
      activityMatchId: 'activity-match-1',
      activitySettingId: 'setting-discount-1',
      bonus: BonusOffer(
        productMatchId: 'bonus-1',
        title: 'Бонусный товар',
        buyQuantity: 6,
        bonusQuantity: 2,
        oneTimePurchase: oneTimePurchase,
        activitySettingId: 'setting-nplusm-1',
      ),
    );
  }

  group('CartNotifier — механика N+M', () {
    test('бонус не начисляется, пока количество меньше порога', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(), 5);

      expect(cart.state.cartItems.length, 1);
      expect(cart.state.quantityOf('bonus-1'), 0);
    });

    test('при достижении buyQuantity начисляется bonusQuantity', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(), 6);

      final bonusItem = cart.state.items['bonus:buy-1:bonus-1'];
      expect(bonusItem, isNotNull);
      expect(bonusItem!.quantity, 2);
      expect(bonusItem.item.isBonus, isTrue);
      expect(bonusItem.item.formattedPrice, 'бесплатно');
    });

    test('бонус масштабируется на каждый полный порог, если акция повторная', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(oneTimePurchase: false), 13); // 2 полных порога по 6

      final bonusItem = cart.state.items['bonus:buy-1:bonus-1'];
      expect(bonusItem!.quantity, 4); // 2 × 2
    });

    test('при one_time_purchase бонус начисляется не больше одного раза', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(oneTimePurchase: true), 13);

      final bonusItem = cart.state.items['bonus:buy-1:bonus-1'];
      expect(bonusItem!.quantity, 2); // не 4
    });

    test('уменьшение количества ниже порога убирает бонусную позицию', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(), 6);
      expect(cart.state.items.containsKey('bonus:buy-1:bonus-1'), isTrue);

      cart.setQuantity(buyItem(), 3);
      expect(cart.state.items.containsKey('bonus:buy-1:bonus-1'), isFalse);
    });

    test('удаление товара из корзины убирает и его бонус', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(), 6);
      cart.setQuantity(buyItem(), 0);

      expect(cart.state.items, isEmpty);
    });

    test('бонусная позиция не учитывается в сумме заказа', () {
      final cart = CartNotifier();
      cart.setQuantity(buyItem(price: 100), 6);

      // 6 × 100 за основной товар + 0 за бонус
      expect(cart.state.total, 600);
    });

    test('increment/decrement тоже пересчитывают бонус', () {
      final cart = CartNotifier();
      final item = buyItem();
      for (var i = 0; i < 6; i++) {
        cart.increment(item);
      }
      expect(cart.state.items['bonus:buy-1:bonus-1']!.quantity, 2);

      cart.decrement(item);
      expect(cart.state.items.containsKey('bonus:buy-1:bonus-1'), isFalse);
    });

    test('товар без bonus не создаёт лишних позиций', () {
      final cart = CartNotifier();
      const plain = CatalogItem(
        id: 'plain-1',
        productId: 'plain-1',
        title: 'Обычный товар',
        price: 50,
      );
      cart.setQuantity(plain, 10);

      expect(cart.state.items.length, 1);
    });
  });
}
