import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/shared/scheduling/reminders.dart';

void main() {
  final DateTime start = DateTime(2026, 10, 1, 9, 30);

  group('quando enviar', () {
    test('nada antes do primeiro horário', () {
      expect(
        dueReminderOffset(
          appointmentStart: start,
          offsetsHours: const <int>[48, 24, 2],
          alreadyHandled: const <int>{},
          now: DateTime(2026, 9, 29, 9),
        ),
        isNull,
      );
    });

    test('envia o de 48 h quando chega a hora', () {
      expect(
        dueReminderOffset(
          appointmentStart: start,
          offsetsHours: const <int>[48, 24, 2],
          alreadyHandled: const <int>{},
          now: DateTime(2026, 9, 29, 9, 30),
        ),
        48,
      );
    });

    test('vários vencidos: só o mais próximo da consulta', () {
      final DateTime now = DateTime(2026, 9, 30, 20);
      final int? due = dueReminderOffset(
        appointmentStart: start,
        offsetsHours: const <int>[48, 24, 2],
        alreadyHandled: const <int>{},
        now: now,
      );
      expect(due, 24);
      expect(
        skippedOffsets(
          appointmentStart: start,
          offsetsHours: const <int>[48, 24, 2],
          alreadyHandled: const <int>{},
          sending: 24,
          now: now,
        ),
        <int>[48],
      );
    });

    test('não repete e não envia depois do início', () {
      expect(
        dueReminderOffset(
          appointmentStart: start,
          offsetsHours: const <int>[48, 24],
          alreadyHandled: const <int>{48, 24},
          now: DateTime(2026, 10, 1, 8),
        ),
        isNull,
      );
      expect(
        dueReminderOffset(
          appointmentStart: start,
          offsetsHours: const <int>[2],
          alreadyHandled: const <int>{},
          now: DateTime(2026, 10, 1, 10),
        ),
        isNull,
      );
    });
  });

  group('consentimento e preferência', () {
    GuardianContact contact({
      bool consent = true,
      ContactChannel pref = ContactChannel.whatsapp,
      String phone = '+55 11 90000-0001',
    }) => GuardianContact(
      name: 'Responsável Exemplo',
      phone: phone,
      preferred: pref,
      reminderConsent: consent,
    );

    test('com consentimento e WhatsApp preferido: envia', () {
      expect(whatsAppEligibility(contact()), ReminderBlock.none);
    });

    test('sem consentimento: não envia', () {
      expect(
        whatsAppEligibility(contact(consent: false)),
        ReminderBlock.noConsent,
      );
    });

    test('preferência por ligação: não envia pelo WhatsApp', () {
      final GuardianContact c = contact(pref: ContactChannel.telefone);
      expect(whatsAppEligibility(c), ReminderBlock.preferenceNotWhatsApp);
      expect(
        blockReason(ReminderBlock.preferenceNotWhatsApp, c),
        contains('Ligação telefônica'),
      );
    });

    test('telefone inválido', () {
      expect(
        whatsAppEligibility(contact(phone: '1234')),
        ReminderBlock.invalidPhone,
      );
      expect(normalizePhone('+55 (11) 90000-0001'), '5511900000001');
      expect(maskPhone('+55 11 90000-0001'), '•••• 0001');
    });
  });

  test('texto discreto: sem motivo, sem sobrenome, com opções', () {
    final String text = reminderText(
      guardianFirstName: 'Ana',
      childFirstName: 'Luna',
      clinicName: 'Consultório Exemplo',
      start: start,
      teleconsulta: false,
    );
    expect(text, contains('Luna'));
    expect(text, contains('qui, 01/10 às 09:30'));
    expect(text, contains('presencial'));
    for (final String sensitive in <String>[
      'febre',
      'tosse',
      'retorno',
      'diagn',
      'exame',
      'Souza',
      'pediatr',
    ]) {
      expect(text.toLowerCase(), isNot(contains(sensitive.toLowerCase())));
    }
  });

  test('payload dos botões', () {
    expect(ReminderReply.fromPayload('r12:confirmar'), ReminderReply.confirmar);
    expect(ReminderReply.fromPayload('r12:reagendar'), ReminderReply.reagendar);
    expect(ReminderReply.fromPayload('r12:cancelar'), ReminderReply.cancelar);
    expect(ReminderReply.fromPayload('lixo'), isNull);
  });

  test('configuração dos intervalos', () {
    expect(const ReminderSettings().validate(), isNull);
    expect(
      const ReminderSettings(offsetsHours: <int>[]).validate(),
      isNotNull,
    );
    expect(
      const ReminderSettings(offsetsHours: <int>[24, 24]).validate(),
      isNotNull,
    );
    expect(
      const ReminderSettings(offsetsHours: <int>[1, 2, 3, 4]).validate(),
      isNotNull,
    );
    expect(const ReminderSettings(offsetsHours: <int>[2, 48]).sorted, <int>[
      48,
      2,
    ]);
    expect(offsetLabel(48), '2 dias antes');
    expect(offsetLabel(2), '2 horas antes');
  });
}
