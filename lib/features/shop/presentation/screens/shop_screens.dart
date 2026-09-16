import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../data/shop_repository.dart';
import '../providers/shop_providers.dart';

// --------------------------------------------------------------- Catálogo

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Product>> products = ref.watch(productsProvider);
    final ProductCategory? category = ref.watch(shopCategoryProvider);
    final Cart cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Badge.count(
              count: cart.itemCount,
              isLabelVisible: cart.itemCount > 0,
              child: IconButton(
                onPressed: () => context.push(Routes.cartPath),
                icon: const Icon(Icons.shopping_bag_outlined),
                tooltip: 'Carrinho',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: const Text('Tudo'),
                    selected: category == null,
                    onSelected: (_) =>
                        ref.read(shopCategoryProvider.notifier).set(null),
                  ),
                ),
                for (final ProductCategory c in ProductCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: category == c,
                      onSelected: (_) =>
                          ref.read(shopCategoryProvider.notifier).set(c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const SkeletonList(itemCount: 4, itemHeight: 88),
              error: (Object e, StackTrace s) => EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Loja indisponível',
                message: 'Não foi possível carregar os produtos agora.',
                actionLabel: 'Tentar de novo',
                onAction: () => ref.invalidate(productsProvider),
              ),
              data: (List<Product> list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Nenhum produto',
                    message: 'Os produtos são cadastrados pelo painel '
                        'administrativo.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: list.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: context.responsive<int>(
                        compact: 2,
                        medium: 3,
                        expanded: 4,
                      ),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.62,
                    ),
                    itemBuilder: (BuildContext context, int index) =>
                        _ProductCard(product: list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.product(product.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _ProductImage(url: product.imageUrl, displayWidth: 180),
                  if (product.hasDiscount)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: AppTag(
                        label: '-${product.discountPercent}%',
                        color: AppColors.raspberry,
                      ),
                    ),
                  if (!product.inStock)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: AppTag(
                          label: 'Esgotado',
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (product.brand != null)
                    Text(
                      product.brand!.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (product.hasDiscount)
                    Text(
                      formatCents(product.compareAtPriceCents!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    formatCents(product.priceCents),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, this.displayWidth});

  final String? url;

  /// Largura lógica aproximada de exibição, em pixels.
  ///
  /// Sem isso, `CachedNetworkImage` decodifica na resolução original do
  /// arquivo — uma foto de produto tirada num celular moderno facilmente
  /// passa de 3000px de largura. Mostrada numa miniatura de 64px no
  /// carrinho, isso é memória decodificada e nunca usada, e o widget é
  /// reaproveitado de 64px até 260px conforme o lugar. `memCacheWidth` pede
  /// ao cache para já guardar na resolução que será exibida.
  ///
  /// Multiplicado por 2 como aproximação de tela de alta densidade — não é
  /// preciso por dispositivo, é para não ficar granulado nas mais comuns.
  final double? displayWidth;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Image.asset(AppAssets.productPlaceholder, fit: BoxFit.cover);
    }

    final int? cacheWidth =
        displayWidth == null ? null : (displayWidth! * 2).round();

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      placeholder: (_, __) =>
          const Skeleton(radius: BorderRadius.zero, height: double.infinity),
      errorWidget: (_, __, ___) =>
          Image.asset(AppAssets.productPlaceholder, fit: BoxFit.cover),
    );
  }
}

// ---------------------------------------------------------------- Produto

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Product> product = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push(Routes.cartPath),
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Carrinho',
          ),
        ],
      ),
      body: product.when(
        loading: () => const LoadingState(),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Produto indisponível',
          message: 'Ele pode ter saído do catálogo.',
        ),
        data: (Product p) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[
            SizedBox(
              height: 260,
              child: _ProductImage(url: p.imageUrl, displayWidth: 400),
            ),
            ContentBounds(
              maxWidth: 620,
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  if (p.brand != null)
                    Text(
                      p.brand!.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                  Text(p.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        formatCents(p.priceCents),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (p.hasDiscount) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            formatCents(p.compareAtPriceCents!),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (p.requiresPrescription)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Este produto exige receita. A compra passa por '
                              'conferência da nossa equipe — fale com o '
                              'atendimento.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!p.inStock)
                    const AppTag(
                      label: 'Fora de estoque',
                      color: AppColors.danger,
                    )
                  else
                    AppButton(
                      label: 'Adicionar ao carrinho',
                      icon: Icons.add_shopping_cart_rounded,
                      onPressed: () async {
                        await ref.read(cartProvider.notifier).add(p);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: const Text('Adicionado ao carrinho.'),
                              action: SnackBarAction(
                                label: 'Ver',
                                onPressed: () =>
                                    context.push(Routes.cartPath),
                              ),
                            ),
                          );
                      },
                    ),
                  const SectionHeader(title: 'Sobre o produto'),
                  Text(
                    p.description,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Suplementos e produtos infantis não substituem orientação '
                    'do pediatra. Converse com quem acompanha sua criança '
                    'antes de introduzir qualquer suplementação.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Carrinho

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Cart cart = ref.watch(cartProvider);
    final AsyncValue<OrderQuote> quote = ref.watch(orderQuoteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrinho'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Carrinho vazio',
              message: 'Os itens que você adicionar aparecem aqui.',
              actionLabel: 'Ver produtos',
              onAction: () => context.go(Routes.shopPath),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                ContentBounds(
                  maxWidth: 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final CartItem item in cart.items)
                        _CartTile(item: item),
                      const SizedBox(height: AppSpacing.lg),
                      _CouponField(current: cart.couponCode),
                      const SizedBox(height: AppSpacing.lg),
                      quote.when(
                        loading: () => const Card(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: LoadingState(label: 'Calculando...'),
                          ),
                        ),
                        error: (Object e, StackTrace s) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Não foi possível calcular o total agora.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(orderQuoteProvider),
                                  child: const Text('Tentar de novo'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (OrderQuote q) => _Summary(quote: q),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Finalizar compra',
                        onPressed: quote.valueOrNull == null
                            ? null
                            : () => context.push(Routes.checkoutPath),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _ProductImage(url: item.imageUrl, displayWidth: 64),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatCents(item.unitPriceCents),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatCents(item.totalCents),
                    style: theme.textTheme.titleSmall,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .setQuantity(item.productId, item.quantity - 1),
                        icon: Icon(
                          item.quantity == 1
                              ? Icons.delete_outline_rounded
                              : Icons.remove_rounded,
                          size: 18,
                        ),
                        tooltip: item.quantity == 1
                            ? 'Remover do carrinho'
                            : 'Diminuir quantidade',
                      ),
                      Text(
                        '${item.quantity}',
                        style: theme.textTheme.titleSmall,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .setQuantity(item.productId, item.quantity + 1),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        tooltip: 'Aumentar quantidade',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponField extends ConsumerStatefulWidget {
  const _CouponField({required this.current});

  final String? current;

  @override
  ConsumerState<_CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends ConsumerState<_CouponField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<OrderQuote> quote = ref.watch(orderQuoteProvider);
    final OrderQuote? q = quote.valueOrNull;

    return AppTextField(
      label: 'Cupom de desconto',
      controller: _controller,
      prefixIcon: Icons.local_offer_outlined,
      textCapitalization: TextCapitalization.characters,
      helper: q?.couponMessage,
      suffix: TextButton(
        onPressed: () async {
          await ref
              .read(cartProvider.notifier)
              .applyCoupon(_controller.text);
          ref.invalidate(orderQuoteProvider);
        },
        child: const Text('Aplicar'),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.quote});

  final OrderQuote quote;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: bold
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                value,
                style: bold
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            // Preço mudou entre navegar e fechar o pedido: melhor descobrir
            // aqui do que depois de pagar.
            if (quote.priceChanges.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Preços atualizados',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final PriceChange change in quote.priceChanges)
                      Text(
                        '${change.name}: '
                        '${formatCents(change.oldPriceCents)} → '
                        '${formatCents(change.newPriceCents)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (quote.unavailable.isNotEmpty) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  'Indisponíveis: ${quote.unavailable.join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            row('Subtotal', formatCents(quote.subtotalCents)),
            if (quote.discountCents > 0)
              row('Desconto', '− ${formatCents(quote.discountCents)}'),
            row(
              'Frete',
              quote.shippingCents == 0
                  ? 'Grátis'
                  : formatCents(quote.shippingCents),
            ),
            const Divider(height: AppSpacing.xl),
            row('Total', formatCents(quote.totalCents), bold: true),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Checkout

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _zip = TextEditingController();
  final TextEditingController _street = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _complement = TextEditingController();
  final TextEditingController _district = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _state = TextEditingController();

  String _payment = 'pix';
  bool _hydrated = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _zip, _street, _number, _complement, _district, _city, _state,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(ShippingAddress address) {
    if (_hydrated) return;
    _hydrated = true;
    _zip.text = address.zipCode;
    _street.text = address.street;
    _number.text = address.number;
    _complement.text = address.complement ?? '';
    _district.text = address.district;
    _city.text = address.city;
    _state.text = address.state;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ShippingAddress address = ShippingAddress(
      zipCode: _zip.text.trim(),
      street: _street.text.trim(),
      number: _number.text.trim(),
      complement: _complement.text.trim(),
      district: _district.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim().toUpperCase(),
    );

    await saveAddress(ref, address);

    final String? orderId =
        await ref.read(checkoutControllerProvider.notifier).submit(
              address: address,
              paymentMethod: _payment,
            );

    if (!mounted) return;

    if (orderId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido registrado.')),
      );
      context.go(Routes.ordersPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CheckoutState state = ref.watch(checkoutControllerProvider);
    final AsyncValue<OrderQuote> quote = ref.watch(orderQuoteProvider);

    final ShippingAddress? saved = ref.watch(savedAddressProvider);
    if (saved != null) _hydrate(saved);

    ref.listen<CheckoutState>(checkoutControllerProvider,
        (CheckoutState? previous, CheckoutState next) {
      if (next.failure != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar compra'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ContentBounds(
          maxWidth: 560,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SectionHeader(title: 'Entrega', eyebrow: 'Endereço'),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'CEP',
                        controller: _zip,
                        keyboardType: TextInputType.number,
                        inputFormatters: Masks.digitsOnly,
                        validator: (String? v) =>
                            (v == null || v.replaceAll(RegExp(r'\D'), '').length != 8)
                                ? 'CEP tem 8 dígitos.'
                                : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Cidade',
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        validator: (String? v) =>
                            Validators.required(v, field: 'A cidade'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Rua',
                  controller: _street,
                  textCapitalization: TextCapitalization.words,
                  validator: (String? v) =>
                      Validators.required(v, field: 'A rua'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Número',
                        controller: _number,
                        validator: (String? v) =>
                            Validators.required(v, field: 'O número'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: 'Complemento',
                        controller: _complement,
                        hint: 'Apto 42',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        label: 'Bairro',
                        controller: _district,
                        textCapitalization: TextCapitalization.words,
                        validator: (String? v) =>
                            Validators.required(v, field: 'O bairro'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'UF',
                        controller: _state,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        validator: (String? v) => (v == null || v.length != 2)
                            ? 'Use a sigla.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SectionHeader(title: 'Pagamento'),
                Card(
                  child: Column(
                    children: <Widget>[
                      RadioListTile<String>(
                        value: 'pix',
                        groupValue: _payment,
                        onChanged: (String? v) =>
                            setState(() => _payment = v ?? 'pix'),
                        title: const Text('Pix'),
                        subtitle: const Text('Aprovação imediata'),
                      ),
                      RadioListTile<String>(
                        value: 'credit_card',
                        groupValue: _payment,
                        onChanged: (String? v) =>
                            setState(() => _payment = v ?? 'pix'),
                        title: const Text('Cartão de crédito'),
                      ),
                      RadioListTile<String>(
                        value: 'boleto',
                        groupValue: _payment,
                        onChanged: (String? v) =>
                            setState(() => _payment = v ?? 'pix'),
                        title: const Text('Boleto'),
                        subtitle: const Text('Compensa em até 3 dias úteis'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (quote.valueOrNull != null) _Summary(quote: quote.value!),
                const SizedBox(height: AppSpacing.xl),
                // Desativado por AppConfig.paymentGatewayEnabled até o
                // gateway real estar integrado. O texto anterior prometia
                // processamento automático e comprovante por e-mail —
                // nenhum dos dois acontece hoje, e deixar o botão ativo
                // levaria o usuário a achar que comprou algo.
                if (!AppConfig.paymentGatewayEnabled)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.10),
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Pagamento indisponível nesta versão. A loja '
                            'ainda não processa compras — nenhum valor será '
                            'cobrado.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Confirmar pedido',
                  isLoading: state.isSubmitting,
                  onPressed:
                      AppConfig.paymentGatewayEnabled ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Pedidos

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Order>> orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus pedidos'),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: orders.when(
        loading: () => const SkeletonList(itemCount: 3, itemHeight: 80),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Não foi possível carregar',
          message: 'Tente novamente em instantes.',
        ),
        data: (List<Order> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhum pedido ainda',
              message: 'Seus pedidos aparecem aqui depois da primeira compra.',
              actionLabel: 'Ver produtos',
              onAction: () => context.go(Routes.shopPath),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final Order order = list[index];

              return ContentBounds(
                maxWidth: 620,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Pedido ${order.id.substring(0, 6).toUpperCase()}',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            AppTag(
                              label: order.status.label,
                              color: switch (order.status) {
                                OrderStatus.delivered => AppColors.success,
                                OrderStatus.cancelled ||
                                OrderStatus.refunded =>
                                  AppColors.danger,
                                OrderStatus.pending => AppColors.warning,
                                _ => AppColors.vital,
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          Formatters.date(order.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          order.items
                              .map((CartItem i) => '${i.quantity}× ${i.name}')
                              .join(', '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: order.trackingCode == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      'Rastreio: ${order.trackingCode}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                            ),
                            Text(
                              formatCents(order.totalCents),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
