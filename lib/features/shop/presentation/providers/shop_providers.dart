import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/shop_repository.dart';

final Provider<ShopRepository> shopRepositoryProvider =
    Provider<ShopRepository>(
  (Ref ref) => ShopRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    cache: ref.watch(cacheServiceProvider),
  ),
);

final NotifierProvider<ShopFilterController, ProductCategory?>
    shopCategoryProvider =
    NotifierProvider<ShopFilterController, ProductCategory?>(
  ShopFilterController.new,
);

class ShopFilterController extends Notifier<ProductCategory?> {
  @override
  ProductCategory? build() => null;

  void set(ProductCategory? category) => state = category;
}

final FutureProvider<List<Product>> productsProvider =
    FutureProvider<List<Product>>((Ref ref) async {
  final ShopRepository repository = ref.watch(shopRepositoryProvider);
  final ProductCategory? category = ref.watch(shopCategoryProvider);

  final Result<List<Product>> result =
      await repository.catalog(category: category);

  return result.fold(
    (List<Product> products) => products,
    (Failure failure) {
      final List<Product> cached = repository.cachedCatalog();
      if (cached.isNotEmpty && category == null) return cached;
      throw failure;
    },
  );
});

final FutureProviderFamily<Product, String> productProvider =
    FutureProvider.family<Product, String>((Ref ref, String id) async {
  final Result<Product> result =
      await ref.watch(shopRepositoryProvider).product(id);

  return result.fold(
    (Product p) {
      ref.read(analyticsProvider).logEvent(
        AnalyticsEvent.productViewed,
        <String, Object>{'item_id': p.id, 'value': p.priceCents / 100},
      );
      return p;
    },
    (Failure failure) => throw failure,
  );
});

/// Carrinho, persistido localmente.
///
/// Fica no Hive, não no Firestore: um carrinho é rascunho, e sincronizá-lo
/// gastaria escrita a cada toque no botão "+". Ele sobrevive a fechar o app,
/// que é o que importa.
class CartController extends Notifier<Cart> {
  static const String _key = 'shop:cart';

  @override
  Cart build() {
    final CacheService cache = ref.watch(cacheServiceProvider);
    final Map<String, dynamic>? saved = cache.readMap(_key);

    if (saved == null) return const Cart();

    try {
      final List<dynamic> items =
          (saved['items'] as List<dynamic>?) ?? const <dynamic>[];
      return Cart(
        items: items
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> m) =>
                CartItem.fromMap(Map<String, dynamic>.from(m)))
            .toList(growable: false),
        couponCode: saved['couponCode'] as String?,
      );
    } catch (_) {
      return const Cart();
    }
  }

  Future<void> _persist(Cart cart) async {
    state = cart;
    await ref.read(cacheServiceProvider).write(_key, <String, dynamic>{
      'items':
          cart.items.map((CartItem i) => i.toMap()).toList(growable: false),
      'couponCode': cart.couponCode,
    });
  }

  Future<void> add(Product product, {int quantity = 1}) async {
    await _persist(state.add(product, quantity: quantity));

    ref.read(analyticsProvider).logEvent(
      AnalyticsEvent.addedToCart,
      <String, Object>{
        'item_id': product.id,
        'quantity': quantity,
        'value': product.priceCents / 100,
      },
    );
  }

  Future<void> setQuantity(String productId, int quantity) =>
      _persist(state.setQuantity(productId, quantity));

  Future<void> remove(String productId) =>
      _persist(state.remove(productId));

  Future<void> applyCoupon(String? code) => _persist(
        state.withCoupon(
          code == null || code.trim().isEmpty ? null : code.trim().toUpperCase(),
        ),
      );

  Future<void> clear() => _persist(state.clear());
}

final NotifierProvider<CartController, Cart> cartProvider =
    NotifierProvider<CartController, Cart>(CartController.new);

/// Prévia do pedido calculada pelo servidor.
///
/// `autoDispose` porque a cotação envelhece: sair do checkout e voltar meia
/// hora depois precisa recalcular, não reaproveitar.
final AutoDisposeFutureProvider<OrderQuote> orderQuoteProvider =
    FutureProvider.autoDispose<OrderQuote>((Ref ref) async {
  final Cart cart = ref.watch(cartProvider);
  if (cart.isEmpty) {
    return const OrderQuote(
      subtotalCents: 0,
      shippingCents: 0,
      discountCents: 0,
      totalCents: 0,
    );
  }

  final Result<OrderQuote> result =
      await ref.watch(shopRepositoryProvider).quote(cart: cart);

  return result.fold(
    (OrderQuote quote) => quote,
    (Failure failure) => throw failure,
  );
});

final StreamProvider<List<Order>> ordersProvider =
    StreamProvider<List<Order>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream<List<Order>>.value(const <Order>[]);
  return ref.watch(shopRepositoryProvider).watchOrders(uid);
});

/// Estado do checkout.
class CheckoutState {
  const CheckoutState({
    this.isSubmitting = false,
    this.failure,
    this.createdOrderId,
  });

  final bool isSubmitting;
  final Failure? failure;
  final String? createdOrderId;
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  Future<String?> submit({
    required ShippingAddress address,
    required String paymentMethod,
  }) async {
    state = const CheckoutState(isSubmitting: true);

    final Cart cart = ref.read(cartProvider);

    ref.read(analyticsProvider).logEvent(
      AnalyticsEvent.checkoutStarted,
      <String, Object>{'value': cart.subtotalCents / 100},
    );

    final Result<OrderCreated> result =
        await ref.read(shopRepositoryProvider).createOrder(
              cart: cart,
              address: address,
              paymentMethod: paymentMethod,
            );

    return result.fold(
      (OrderCreated created) {
        // Só limpa o carrinho depois de o servidor confirmar. Limpar antes
        // perderia o pedido inteiro se a chamada falhasse.
        ref.read(cartProvider.notifier).clear();

        ref.read(analyticsProvider).logPurchase(
              orderId: created.orderId,
              value: created.totalCents / 100,
            );

        state = CheckoutState(createdOrderId: created.orderId);
        return created.orderId;
      },
      (Failure failure) {
        state = CheckoutState(failure: failure);
        return null;
      },
    );
  }

  void reset() => state = const CheckoutState();
}

final NotifierProvider<CheckoutController, CheckoutState>
    checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);

/// Endereço salvo do usuário, para não redigitar a cada compra.
final Provider<ShippingAddress?> savedAddressProvider =
    Provider<ShippingAddress?>((Ref ref) {
  final Map<String, dynamic>? saved =
      ref.watch(cacheServiceProvider).readMap('shop:address');
  return saved == null ? null : ShippingAddress.fromMap(saved);
});

Future<void> saveAddress(WidgetRef ref, ShippingAddress address) =>
    ref.read(cacheServiceProvider).write(
          'shop:address',
          jsonDecode(jsonEncode(address.toMap())) as Map<String, dynamic>,
        );
