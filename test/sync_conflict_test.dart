import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/services/sync_conflict.dart';

void main() {
  group('estratégia por entidade', () {
    test('medição mantém as duas versões', () {
      // Medição é evento, não estado: duas no mesmo dia são dois fatos.
      expect(
        ConflictResolver.strategyFor('growth_records'),
        ConflictStrategy.keepBoth,
      );
    });

    test('vacina prefere o registro mais antigo', () {
      expect(
        ConflictResolver.strategyFor('vaccine_doses'),
        ConflictStrategy.preferEarliest,
      );
    });

    test('cadastro mescla campo a campo', () {
      expect(
        ConflictResolver.strategyFor('children'),
        ConflictStrategy.mergeFields,
      );
    });

    test('entidade desconhecida cai no último recurso', () {
      expect(
        ConflictResolver.strategyFor('qualquer_coisa'),
        ConflictStrategy.lastWriteWins,
      );
    });
  });

  group('mesclagem de cadastro', () {
    test('edições em campos diferentes não são conflito', () {
      // Mãe edita o telefone no celular, pai adiciona condição no tablet.
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'children',
        local: <String, dynamic>{'phone': '11988887777'},
        remote: <String, dynamic>{'name': 'Manuela', 'bloodType': 'O+'},
      );

      expect(r.hasConflict, isFalse);
      expect(r.merged!['phone'], '11988887777');
      expect(r.merged!['name'], 'Manuela');
      expect(r.merged!['bloodType'], 'O+');
    });

    test('listas são unidas — nenhuma alergia se perde', () {
      // Este é o caso que motivou abandonar "última escrita vence": perder
      // uma alergia numa mesclagem é o tipo de erro que machuca.
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'children',
        local: <String, dynamic>{
          'allergies': <String>['amendoim'],
        },
        remote: <String, dynamic>{
          'allergies': <String>['dipirona'],
        },
      );

      final List<dynamic> merged = r.merged!['allergies'] as List<dynamic>;
      expect(merged, containsAll(<String>['amendoim', 'dipirona']));
      expect(merged.length, 2);
      expect(r.hasConflict, isFalse);
    });

    test('lista sem novidade não duplica', () {
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'children',
        local: <String, dynamic>{
          'allergies': <String>['amendoim'],
        },
        remote: <String, dynamic>{
          'allergies': <String>['amendoim'],
        },
      );
      expect((r.merged!['allergies'] as List<dynamic>).length, 1);
    });

    test('mesmo campo com valores diferentes vira conflito registrado', () {
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'children',
        local: <String, dynamic>{'bloodType': 'O+'},
        remote: <String, dynamic>{'bloodType': 'A+'},
      );

      expect(r.hasConflict, isTrue);
      expect(r.conflictedFields, <String>['bloodType']);
      // O local vence, mas o descartado fica registrado.
      expect(r.merged!['bloodType'], 'O+');
      expect(r.discarded!['bloodType'], 'A+');
    });

    test('campos do servidor não são sobrescritos pelo cliente', () {
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'children',
        local: <String, dynamic>{
          'name': 'Manuela',
          'ownerId': 'tentativa_de_troca',
          'createdAt': 1,
        },
        remote: <String, dynamic>{
          'name': 'Manuela',
          'ownerId': 'dono_real',
          'createdAt': 999,
        },
      );

      expect(r.merged!['ownerId'], 'dono_real');
      expect(r.merged!['createdAt'], 999);
      expect(r.hasConflict, isFalse);
    });
  });

  group('vacina: data mais antiga prevalece', () {
    ConflictResolution resolve(String? local, String? remote) =>
        ConflictResolver.resolve(
          entity: 'vaccine_doses',
          local: <String, dynamic>{'appliedAt': local},
          remote: <String, dynamic>{'appliedAt': remote},
        );

    test('só o servidor marcou: a marcação vence', () {
      final ConflictResolution r = resolve(null, '2026-03-01T10:00:00Z');
      expect(r.shouldWrite, isFalse);
    });

    test('só o local marcou: a marcação vence', () {
      final ConflictResolution r = resolve('2026-03-01T10:00:00Z', null);
      expect(r.shouldWrite, isTrue);
    });

    test('servidor tem data anterior: descarta o local', () {
      // Quem registrou mais perto da aplicação tende a acertar.
      final ConflictResolution r =
          resolve('2026-03-05T10:00:00Z', '2026-03-01T10:00:00Z');
      expect(r.shouldWrite, isFalse);
      expect(r.conflictedFields, <String>['appliedAt']);
    });

    test('local tem data anterior: prevalece', () {
      final ConflictResolution r =
          resolve('2026-03-01T10:00:00Z', '2026-03-05T10:00:00Z');
      expect(r.shouldWrite, isTrue);
      expect(r.conflictedFields, <String>['appliedAt']);
    });

    test('mesma data não é conflito', () {
      final ConflictResolution r =
          resolve('2026-03-01T10:00:00Z', '2026-03-01T10:00:00Z');
      expect(r.hasConflict, isFalse);
    });

    test('nenhum dos dois marcou', () {
      final ConflictResolution r = resolve(null, null);
      expect(r.shouldWrite, isTrue);
      expect(r.hasConflict, isFalse);
    });
  });

  group('medição mantém ambas', () {
    test('não descarta a versão local', () {
      final ConflictResolution r = ConflictResolver.resolve(
        entity: 'growth_records',
        local: <String, dynamic>{'weightKg': 9.6},
        remote: <String, dynamic>{'weightKg': 9.8},
      );

      expect(r.shouldWrite, isTrue);
      expect(r.merged!['weightKg'], 9.6);
      expect(r.hasConflict, isFalse);
    });
  });

  group('espera entre tentativas', () {
    // Ruído fixo em zero para o teste ser determinístico.
    final math.Random noJitter = _FixedRandom(0);

    test('primeira tentativa não espera', () {
      expect(SyncBackoff.delayFor(0), Duration.zero);
    });

    test('cresce exponencialmente', () {
      expect(
        SyncBackoff.delayFor(1, random: noJitter).inMilliseconds,
        4000,
      );
      expect(
        SyncBackoff.delayFor(2, random: noJitter).inMilliseconds,
        8000,
      );
      expect(
        SyncBackoff.delayFor(3, random: noJitter).inMilliseconds,
        16000,
      );
    });

    test('respeita o teto de 30 minutos', () {
      // Sem teto, a 20ª tentativa esperaria mais de 20 dias.
      expect(
        SyncBackoff.delayFor(20, random: noJitter),
        SyncBackoff.ceiling,
      );
    });

    test('o ruído só diminui a espera, nunca aumenta', () {
      // Aumentar passaria do teto e atrasaria a recuperação.
      for (int attempts = 1; attempts <= 10; attempts++) {
        final Duration max = SyncBackoff.delayFor(
          attempts,
          random: _FixedRandom(0),
        );
        final Duration jittered = SyncBackoff.delayFor(
          attempts,
          random: _FixedRandom(0.99),
        );
        expect(jittered <= max, isTrue, reason: 'falhou em $attempts');
      }
    });

    test('o ruído não reduz mais que 25%', () {
      final Duration max = SyncBackoff.delayFor(5, random: _FixedRandom(0));
      final Duration min = SyncBackoff.delayFor(5, random: _FixedRandom(1));
      expect(
        min.inMilliseconds >= (max.inMilliseconds * 0.75).round() - 1,
        isTrue,
      );
    });

    test('sem tentativa anterior está sempre pronto', () {
      expect(
        SyncBackoff.isReady(attempts: 0, lastAttemptAt: null),
        isTrue,
      );
    });

    test('espera cumprida libera nova tentativa', () {
      final DateTime now = DateTime(2026, 7, 20, 12, 0);

      expect(
        SyncBackoff.isReady(
          attempts: 1,
          lastAttemptAt: now.subtract(const Duration(seconds: 1)),
          now: now,
          random: noJitter,
        ),
        isFalse,
      );

      expect(
        SyncBackoff.isReady(
          attempts: 1,
          lastAttemptAt: now.subtract(const Duration(seconds: 10)),
          now: now,
          random: noJitter,
        ),
        isTrue,
      );
    });
  });

  group('histórico de sincronização', () {
    test('ida e volta pela linha do banco', () {
      final SyncEvent event = SyncEvent(
        id: 'e1',
        at: DateTime(2026, 7, 20, 14, 30),
        entity: 'children',
        entityId: 'c1',
        outcome: SyncOutcome.merged,
        strategy: 'mergeFields',
        conflictedFields: const <String>['bloodType', 'phone'],
        attempts: 2,
      );

      final SyncEvent restored = SyncEvent.fromRow(event.toRow());

      expect(restored.id, event.id);
      expect(restored.entity, event.entity);
      expect(restored.outcome, SyncOutcome.merged);
      expect(restored.conflictedFields, <String>['bloodType', 'phone']);
      expect(restored.attempts, 2);
      expect(restored.at, event.at);
    });

    test('lista vazia de conflitos sobrevive à serialização', () {
      final SyncEvent event = SyncEvent(
        id: 'e2',
        at: DateTime(2026, 7, 20),
        entity: 'growth_records',
        entityId: 'g1',
        outcome: SyncOutcome.sent,
      );
      expect(SyncEvent.fromRow(event.toRow()).conflictedFields, isEmpty);
    });

    test('resultados que merecem atenção do usuário', () {
      expect(SyncOutcome.sent.isProblem, isFalse);
      expect(SyncOutcome.merged.isProblem, isFalse);
      expect(SyncOutcome.discardedLocal.isProblem, isTrue);
      expect(SyncOutcome.failed.isProblem, isTrue);
      expect(SyncOutcome.abandoned.isProblem, isTrue);
    });
  });
}

/// Gerador determinístico, para o teste não depender de sorte.
class _FixedRandom implements math.Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}
