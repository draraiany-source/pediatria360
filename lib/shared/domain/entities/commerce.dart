import 'package:equatable/equatable.dart';

/// Categoria de produto do marketplace.
enum ProductCategory {
  supplement,
  hygiene,
  feeding,
  safety,
  book,
  other;

  static ProductCategory fromName(String? value) =>
      ProductCategory.values.firstWhere(
        (ProductCategory c) => c.name == value,
        orElse: () => ProductCategory.other,
      );

  String get label => switch (this) {
        ProductCategory.supplement => 'Suplementos',
        ProductCategory.hygiene => 'Higiene',
        ProductCategory.feeding => 'Alimentação',
        ProductCategory.safety => 'Segurança',
        ProductCategory.book => 'Livros',
        ProductCategory.other => 'Outros',
      };
}

/// Produto à venda.
///
/// Preços são armazenados em **centavos, como inteiro**. Ponto flutuante em
/// dinheiro acumula erro: 0.1 + 0.2 não dá 0.3 em `double`, e num carrinho com
/// dez itens a diferença aparece no total.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.category,
    this.imageUrl,
    this.brand,
    this.compareAtPriceCents,
    this.stock = 0,
    this.published = true,
    this.requiresPrescription = false,
    this.ageRangeMonths,
    this.tags = const <String>[],
    this.rating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String description;

  /// Preço em centavos.
  final int priceCents;

  final ProductCategory category;
  final String? imageUrl;
  final String? brand;

  /// Preço "de", para exibir desconto. Só aparece se for maior que o atual.
  final int? compareAtPriceCents;

  final int stock;
  final bool published;

  /// Exige receita. Produtos assim não entram no carrinho pelo app — a compra
  /// passa por conferência humana.
  final bool requiresPrescription;

  final (int, int)? ageRangeMonths;
  final List<String> tags;
  final double rating;
  final int reviewCount;

  bool get inStock => stock > 0;

  bool get hasDiscount =>
      compareAtPriceCents != null && compareAtPriceCents! > priceCents;

  int get discountPercent => hasDiscount
      ? (((compareAtPriceCents! - priceCents) / compareAtPriceCents!) * 100)
          .round()
      : 0;

  bool suitableFor(int ageMonths) {
    if (ageRangeMonths == null) return true;
    final (int min, int max) = ageRangeMonths!;
    return ageMonths >= min && ageMonths <= max;
  }

  @override
  List<Object?> get props => <Object?>[id, name, priceCents, stock];
}

/// Item no carrinho.
///
/// Guarda o preço visto no momento em que o item foi adicionado. Serve para
/// **detectar mudança de preço** entre a navegação e o checkout — não para
/// definir quanto o cliente paga. O valor cobrado é sempre o que o servidor
/// calcula na hora do pedido.
class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
    this.imageUrl,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
        productId: (map['productId'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        unitPriceCents: (map['unitPriceCents'] as num?)?.toInt() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        imageUrl: map['imageUrl'] as String?,
      );

  final String productId;
  final String name;
  final int unitPriceCents;
  final int quantity;
  final String? imageUrl;

  int get totalCents => unitPriceCents * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        productId: productId,
        name: name,
        unitPriceCents: unitPriceCents,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'productId': productId,
        'name': name,
        'unitPriceCents': unitPriceCents,
        'quantity': quantity,
        'imageUrl': imageUrl,
      };

  @override
  List<Object?> get props => <Object?>[productId, quantity, unitPriceCents];
}

/// Carrinho, mantido localmente.
class Cart extends Equatable {
  const Cart({this.items = const <CartItem>[], this.couponCode});

  final List<CartItem> items;

  /// Código digitado. A validade e o desconto são apurados no servidor — um
  /// cupom validado no cliente seria trivial de forjar.
  final String? couponCode;

  bool get isEmpty => items.isEmpty;

  int get itemCount =>
      items.fold(0, (int sum, CartItem item) => sum + item.quantity);

  int get subtotalCents =>
      items.fold(0, (int sum, CartItem item) => sum + item.totalCents);

  Cart add(Product product, {int quantity = 1}) {
    final int index =
        items.indexWhere((CartItem i) => i.productId == product.id);

    if (index >= 0) {
      final List<CartItem> updated = List<CartItem>.of(items);
      final int newQuantity = updated[index].quantity + quantity;
      // Teto por item: pedidos maiores passam pelo atendimento.
      updated[index] =
          updated[index].copyWith(quantity: newQuantity.clamp(1, 20));
      return Cart(items: updated, couponCode: couponCode);
    }

    return Cart(
      items: <CartItem>[
        ...items,
        CartItem(
          productId: product.id,
          name: product.name,
          unitPriceCents: product.priceCents,
          quantity: quantity.clamp(1, 20),
          imageUrl: product.imageUrl,
        ),
      ],
      couponCode: couponCode,
    );
  }

  Cart setQuantity(String productId, int quantity) {
    if (quantity <= 0) return remove(productId);

    return Cart(
      items: items
          .map(
            (CartItem i) => i.productId == productId
                ? i.copyWith(quantity: quantity.clamp(1, 20))
                : i,
          )
          .toList(growable: false),
      couponCode: couponCode,
    );
  }

  Cart remove(String productId) => Cart(
        items: items
            .where((CartItem i) => i.productId != productId)
            .toList(growable: false),
        couponCode: couponCode,
      );

  Cart withCoupon(String? code) => Cart(items: items, couponCode: code);

  Cart clear() => const Cart();

  @override
  List<Object?> get props => <Object?>[items, couponCode];
}

/// Situação de um pedido.
enum OrderStatus {
  pending,
  paid,
  preparing,
  shipped,
  delivered,
  cancelled,
  refunded;

  static OrderStatus fromName(String? value) => OrderStatus.values.firstWhere(
        (OrderStatus s) => s.name == value,
        orElse: () => OrderStatus.pending,
      );

  String get label => switch (this) {
        OrderStatus.pending => 'Aguardando pagamento',
        OrderStatus.paid => 'Pagamento confirmado',
        OrderStatus.preparing => 'Em separação',
        OrderStatus.shipped => 'A caminho',
        OrderStatus.delivered => 'Entregue',
        OrderStatus.cancelled => 'Cancelado',
        OrderStatus.refunded => 'Reembolsado',
      };

  bool get isFinal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.refunded;
}

/// Pedido, como o servidor o registrou.
///
/// Todos os valores vêm do servidor. O app **exibe**; nunca calcula o que será
/// cobrado.
class Order extends Equatable {
  const Order({
    required this.id,
    required this.ownerId,
    required this.items,
    required this.subtotalCents,
    required this.shippingCents,
    required this.discountCents,
    required this.totalCents,
    required this.status,
    required this.createdAt,
    this.couponCode,
    this.trackingCode,
    this.paymentMethod,
    this.address,
  });

  final String id;
  final String ownerId;
  final List<CartItem> items;
  final int subtotalCents;
  final int shippingCents;
  final int discountCents;
  final int totalCents;
  final OrderStatus status;
  final DateTime createdAt;
  final String? couponCode;
  final String? trackingCode;
  final String? paymentMethod;
  final ShippingAddress? address;

  @override
  List<Object?> get props => <Object?>[id, status, totalCents, createdAt];
}

/// Endereço de entrega.
class ShippingAddress extends Equatable {
  const ShippingAddress({
    required this.zipCode,
    required this.street,
    required this.number,
    required this.district,
    required this.city,
    required this.state,
    this.complement,
    this.recipient,
  });

  factory ShippingAddress.fromMap(Map<String, dynamic> map) => ShippingAddress(
        zipCode: (map['zipCode'] as String?) ?? '',
        street: (map['street'] as String?) ?? '',
        number: (map['number'] as String?) ?? '',
        district: (map['district'] as String?) ?? '',
        city: (map['city'] as String?) ?? '',
        state: (map['state'] as String?) ?? '',
        complement: map['complement'] as String?,
        recipient: map['recipient'] as String?,
      );

  final String zipCode;
  final String street;
  final String number;
  final String district;
  final String city;
  final String state;
  final String? complement;
  final String? recipient;

  String get oneLine => '$street, $number'
      '${complement != null && complement!.isNotEmpty ? ' · $complement' : ''}'
      ' — $district, $city/$state';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'zipCode': zipCode,
        'street': street,
        'number': number,
        'district': district,
        'city': city,
        'state': state,
        'complement': complement,
        'recipient': recipient,
      };

  @override
  List<Object?> get props =>
      <Object?>[zipCode, street, number, district, city, state];
}

/// Formata centavos como moeda brasileira.
String formatCents(int cents) {
  final String value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  // Separador de milhar.
  final List<String> parts = value.split(',');
  final String integer = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (Match m) => '${m[1]}.',
  );
  return 'R\$ $integer,${parts[1]}';
}
