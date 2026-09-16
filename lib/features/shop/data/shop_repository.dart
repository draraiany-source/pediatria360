import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/result.dart';
import '../../../shared/domain/entities/commerce.dart';

/// Acesso ao marketplace.
///
/// ## Onde o preço é decidido
///
/// O app **nunca** envia quanto o pedido custa. Ele envia os ids e as
/// quantidades; a Cloud Function `createOrder` busca cada produto, soma, aplica
/// o cupom e devolve o total. Confiar no valor calculado no cliente é o erro
/// clássico de e-commerce: basta interceptar a requisição e comprar por R$ 0,01.
class ShopRepository {
  const ShopRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required CacheService cache,
  })  : _firestore = firestore,
        _functions = functions,
        _cache = cache;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final CacheService _cache;

  static const String _cacheKey = 'shop:catalog';

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirestorePaths.products);

  // -------------------------------------------------------------- Catálogo

  Future<Result<List<Product>>> catalog({ProductCategory? category}) =>
      guard(() async {
        Query<Map<String, dynamic>> query =
            _products.where('published', isEqualTo: true);

        if (category != null) {
          query = query.where('category', isEqualTo: category.name);
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await query.limit(60).get();

        final List<Product> products = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                _productFrom(d.id, d.data()))
            .toList(growable: false);

        if (category == null) {
          await _cache.write(
            _cacheKey,
            products.map(_productToMap).toList(growable: false),
            ttl: AppConfig.cacheTtlShort,
          );
        }

        return products;
      });

  /// Catálogo do cache. TTL curto (5 min) porque preço e estoque mudam — uma
  /// vitrine desatualizada gera frustração no checkout.
  List<Product> cachedCatalog() => _cache
      .readList(_cacheKey)
      .map((Map<String, dynamic> m) =>
          _productFrom(m['id'] as String? ?? '', m))
      .toList(growable: false);

  Future<Result<Product>> product(String productId) => guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _products.doc(productId).get();
        if (!doc.exists) throw StateError('Produto não encontrado.');
        return _productFrom(doc.id, doc.data()!);
      });

  // -------------------------------------------------------------- Checkout

  /// Prévia do pedido: o servidor recalcula tudo e devolve o que será cobrado.
  ///
  /// Chamado ao abrir o checkout, antes de qualquer pagamento. Se um preço
  /// mudou desde que o item entrou no carrinho, é aqui que o usuário descobre —
  /// e não depois de pagar.
  Future<Result<OrderQuote>> quote({
    required Cart cart,
    String? zipCode,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response =
            await _functions.httpsCallable('quoteOrder').call(
          <String, dynamic>{
            'items': cart.items
                .map(
                  (CartItem i) => <String, dynamic>{
                    'productId': i.productId,
                    'quantity': i.quantity,
                  },
                )
                .toList(),
            if (cart.couponCode != null) 'couponCode': cart.couponCode,
            if (zipCode != null) 'zipCode': zipCode,
          },
        );

        return OrderQuote.fromMap(
          Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>),
        );
      });

  /// Cria o pedido. Devolve o id e a URL de pagamento.
  Future<Result<OrderCreated>> createOrder({
    required Cart cart,
    required ShippingAddress address,
    required String paymentMethod,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response =
            await _functions.httpsCallable('createOrder').call(
          <String, dynamic>{
            'items': cart.items
                .map(
                  (CartItem i) => <String, dynamic>{
                    'productId': i.productId,
                    'quantity': i.quantity,
                  },
                )
                .toList(),
            'address': address.toMap(),
            'paymentMethod': paymentMethod,
            if (cart.couponCode != null) 'couponCode': cart.couponCode,
          },
        );

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        return OrderCreated(
          orderId: (data['orderId'] as String?) ?? '',
          paymentUrl: data['paymentUrl'] as String?,
          totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
        );
      });

  /// Pedidos do usuário.
  Stream<List<Order>> watchOrders(String uid) => _firestore
      .collection(FirestorePaths.orders)
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                _orderFrom(d.id, d.data()))
            .toList(growable: false),
      );

  // ------------------------------------------------------------ Conversores

  static Product _productFrom(String id, Map<String, dynamic> data) {
    final List<dynamic> range =
        (data['ageRangeMonths'] as List<dynamic>?) ?? const <dynamic>[];

    return Product(
      id: id,
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      category: ProductCategory.fromName(data['category'] as String?),
      imageUrl: data['imageUrl'] as String?,
      brand: data['brand'] as String?,
      compareAtPriceCents: (data['compareAtPriceCents'] as num?)?.toInt(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      published: (data['published'] as bool?) ?? true,
      requiresPrescription: (data['requiresPrescription'] as bool?) ?? false,
      ageRangeMonths: range.length == 2
          ? ((range[0] as num).toInt(), (range[1] as num).toInt())
          : null,
      tags: (data['tags'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> _productToMap(Product p) => <String, dynamic>{
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'priceCents': p.priceCents,
        'category': p.category.name,
        'imageUrl': p.imageUrl,
        'brand': p.brand,
        'compareAtPriceCents': p.compareAtPriceCents,
        'stock': p.stock,
        'published': p.published,
        'requiresPrescription': p.requiresPrescription,
        'ageRangeMonths': p.ageRangeMonths == null
            ? null
            : <int>[p.ageRangeMonths!.$1, p.ageRangeMonths!.$2],
        'tags': p.tags,
        'rating': p.rating,
        'reviewCount': p.reviewCount,
      };

  static Order _orderFrom(String id, Map<String, dynamic> data) => Order(
        id: id,
        ownerId: (data['ownerId'] as String?) ?? '',
        items: ((data['items'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> m) =>
                CartItem.fromMap(Map<String, dynamic>.from(m)))
            .toList(growable: false),
        subtotalCents: (data['subtotalCents'] as num?)?.toInt() ?? 0,
        shippingCents: (data['shippingCents'] as num?)?.toInt() ?? 0,
        discountCents: (data['discountCents'] as num?)?.toInt() ?? 0,
        totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
        status: OrderStatus.fromName(data['status'] as String?),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        couponCode: data['couponCode'] as String?,
        trackingCode: data['trackingCode'] as String?,
        paymentMethod: data['paymentMethod'] as String?,
        address: data['address'] == null
            ? null
            : ShippingAddress.fromMap(
                Map<String, dynamic>.from(
                  data['address'] as Map<dynamic, dynamic>,
                ),
              ),
      );
}

/// Prévia calculada pelo servidor.
class OrderQuote {
  const OrderQuote({
    required this.subtotalCents,
    required this.shippingCents,
    required this.discountCents,
    required this.totalCents,
    this.couponValid = false,
    this.couponMessage,
    this.priceChanges = const <PriceChange>[],
    this.unavailable = const <String>[],
  });

  factory OrderQuote.fromMap(Map<String, dynamic> map) => OrderQuote(
        subtotalCents: (map['subtotalCents'] as num?)?.toInt() ?? 0,
        shippingCents: (map['shippingCents'] as num?)?.toInt() ?? 0,
        discountCents: (map['discountCents'] as num?)?.toInt() ?? 0,
        totalCents: (map['totalCents'] as num?)?.toInt() ?? 0,
        couponValid: (map['couponValid'] as bool?) ?? false,
        couponMessage: map['couponMessage'] as String?,
        priceChanges:
            ((map['priceChanges'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<dynamic, dynamic>>()
                .map((Map<dynamic, dynamic> m) =>
                    PriceChange.fromMap(Map<String, dynamic>.from(m)))
                .toList(growable: false),
        unavailable: (map['unavailable'] as List<dynamic>?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const <String>[],
      );

  final int subtotalCents;
  final int shippingCents;
  final int discountCents;
  final int totalCents;
  final bool couponValid;
  final String? couponMessage;

  /// Itens cujo preço mudou desde que entraram no carrinho.
  final List<PriceChange> priceChanges;

  /// Produtos que saíram de estoque ou foram despublicados.
  final List<String> unavailable;

  bool get hasIssues => priceChanges.isNotEmpty || unavailable.isNotEmpty;
}

class PriceChange {
  const PriceChange({
    required this.productId,
    required this.name,
    required this.oldPriceCents,
    required this.newPriceCents,
  });

  factory PriceChange.fromMap(Map<String, dynamic> map) => PriceChange(
        productId: (map['productId'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        oldPriceCents: (map['oldPriceCents'] as num?)?.toInt() ?? 0,
        newPriceCents: (map['newPriceCents'] as num?)?.toInt() ?? 0,
      );

  final String productId;
  final String name;
  final int oldPriceCents;
  final int newPriceCents;

  bool get increased => newPriceCents > oldPriceCents;
}

class OrderCreated {
  const OrderCreated({
    required this.orderId,
    required this.totalCents,
    this.paymentUrl,
  });

  final String orderId;
  final int totalCents;
  final String? paymentUrl;
}
