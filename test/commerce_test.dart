import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';
import 'package:pediatria360/shared/domain/entities/commerce.dart';

Product product({
  String id = 'p1',
  int priceCents = 1990,
  int stock = 10,
  int? compareAt,
}) =>
    Product(
      id: id,
      name: 'Produto $id',
      description: '',
      priceCents: priceCents,
      category: ProductCategory.supplement,
      stock: stock,
      compareAtPriceCents: compareAt,
    );

void main() {
  group('formatação de moeda', () {
    // Valores em centavos evitam o erro de ponto flutuante: 0.1 + 0.2 não dá
    // 0.3 em double, e num carrinho de dez itens isso aparece no total.
    test('centavos viram reais com vírgula', () {
      expect(formatCents(0), r'R$ 0,00');
      expect(formatCents(50), r'R$ 0,50');
      expect(formatCents(990), r'R$ 9,90');
      expect(formatCents(1000), r'R$ 10,00');
    });

    test('separador de milhar', () {
      expect(formatCents(100000), r'R$ 1.000,00');
      expect(formatCents(1234567), r'R$ 12.345,67');
      expect(formatCents(999999999), r'R$ 9.999.999,99');
    });
  });

  group('desconto do produto', () {
    test('sem preço anterior não há desconto', () {
      expect(product().hasDiscount, isFalse);
      expect(product().discountPercent, 0);
    });

    test('calcula o percentual', () {
      final Product p = product(priceCents: 7500, compareAt: 10000);
      expect(p.hasDiscount, isTrue);
      expect(p.discountPercent, 25);
    });

    test('preço anterior menor não conta como desconto', () {
      final Product p = product(priceCents: 10000, compareAt: 7500);
      expect(p.hasDiscount, isFalse);
    });
  });

  group('carrinho', () {
    test('começa vazio', () {
      const Cart cart = Cart();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotalCents, 0);
    });

    test('adicionar cria item', () {
      final Cart cart = const Cart().add(product());
      expect(cart.itemCount, 1);
      expect(cart.subtotalCents, 1990);
    });

    test('adicionar o mesmo produto soma a quantidade', () {
      final Cart cart = const Cart().add(product()).add(product());
      expect(cart.items.length, 1);
      expect(cart.itemCount, 2);
      expect(cart.subtotalCents, 3980);
    });

    test('produtos diferentes viram itens distintos', () {
      final Cart cart = const Cart()
          .add(product(id: 'a', priceCents: 1000))
          .add(product(id: 'b', priceCents: 2500));
      expect(cart.items.length, 2);
      expect(cart.subtotalCents, 3500);
    });

    test('quantidade é limitada a 20 por item', () {
      // Pedidos maiores passam pelo atendimento, não pelo app.
      final Cart cart = const Cart().add(product(), quantity: 50);
      expect(cart.items.first.quantity, 20);
    });

    test('somar além do teto não ultrapassa 20', () {
      final Cart cart =
          const Cart().add(product(), quantity: 15).add(product(), quantity: 15);
      expect(cart.items.first.quantity, 20);
    });

    test('quantidade zero remove o item', () {
      final Cart cart = const Cart().add(product()).setQuantity('p1', 0);
      expect(cart.isEmpty, isTrue);
    });

    test('quantidade negativa também remove', () {
      final Cart cart = const Cart().add(product()).setQuantity('p1', -3);
      expect(cart.isEmpty, isTrue);
    });

    test('remover item específico preserva os demais', () {
      final Cart cart = const Cart()
          .add(product(id: 'a'))
          .add(product(id: 'b'))
          .remove('a');
      expect(cart.items.length, 1);
      expect(cart.items.first.productId, 'b');
    });

    test('cupom é normalizado em caixa alta pelo controlador', () {
      final Cart cart = const Cart().withCoupon('BEMVINDO10');
      expect(cart.couponCode, 'BEMVINDO10');
    });

    test('limpar esvazia tudo', () {
      final Cart cart = const Cart().add(product()).clear();
      expect(cart.isEmpty, isTrue);
      expect(cart.couponCode, isNull);
    });
  });

  group('faixa etária do produto', () {
    test('sem faixa serve para qualquer idade', () {
      expect(product().suitableFor(0), isTrue);
      expect(product().suitableFor(200), isTrue);
    });

    test('respeita os limites', () {
      final Product p = Product(
        id: 'p',
        name: '',
        description: '',
        priceCents: 100,
        category: ProductCategory.feeding,
        ageRangeMonths: (6, 24),
      );
      expect(p.suitableFor(5), isFalse);
      expect(p.suitableFor(6), isTrue);
      expect(p.suitableFor(24), isTrue);
      expect(p.suitableFor(25), isFalse);
    });
  });

  group('consulta', () {
    Appointment build({
      required DateTime startsAt,
      AppointmentStatus status = AppointmentStatus.confirmed,
    }) =>
        Appointment(
          id: 'a1',
          patientId: 'u1',
          professionalId: 'd1',
          professionalName: 'Dra. Ana',
          startsAt: startsAt,
          durationMinutes: 30,
          status: status,
          createdAt: DateTime.now(),
        );

    test('sala fechada muito antes do horário', () {
      final Appointment a =
          build(startsAt: DateTime.now().add(const Duration(hours: 2)));
      expect(a.canEnterRoom, isFalse);
    });

    test('sala abre 10 minutos antes', () {
      final Appointment a =
          build(startsAt: DateTime.now().add(const Duration(minutes: 5)));
      expect(a.canEnterRoom, isTrue);
    });

    test('consulta cancelada nunca abre a sala', () {
      final Appointment a = build(
        startsAt: DateTime.now(),
        status: AppointmentStatus.cancelled,
      );
      expect(a.canEnterRoom, isFalse);
    });

    test('sala fecha 15 minutos depois do fim', () {
      final Appointment a = build(
        startsAt: DateTime.now().subtract(const Duration(minutes: 50)),
      );
      expect(a.canEnterRoom, isFalse);
    });

    test('cancelamento gratuito até 24 h antes', () {
      expect(
        build(startsAt: DateTime.now().add(const Duration(hours: 30)))
            .canCancelFree,
        isTrue,
      );
      expect(
        build(startsAt: DateTime.now().add(const Duration(hours: 5)))
            .canCancelFree,
        isFalse,
      );
    });
  });
}
