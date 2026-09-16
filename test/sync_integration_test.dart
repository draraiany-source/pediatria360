import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/services/sync_conflict.dart';

/// Simulação de dois aparelhos editando o mesmo dado.
///
/// ## Por que simular em vez de testar contra o Firestore
///
/// O que precisa ser verificado aqui é a **decisão** de resolução, não a
/// escrita. Um teste contra emulador verificaria as duas coisas juntas e
/// falharia por rede quando o problema fosse lógica — e vice-versa.
///
/// A escrita já é coberta pelos 47 testes de regras. Aqui isolamos o miolo:
/// dados os estados de dois aparelhos e do servidor, o que fica no fim?
class _Device {
  _Device(this.name);

  final String name;

  /// Estado local, como está no SQLite do aparelho.
  Map<String, dynamic> local = <String, dynamic>{};

  /// Momento em que a escrita entrou na fila de envio.
  DateTime? queuedAt;

  void edit(Map<String, dynamic> changes, {required DateTime at}) {
    local = <String, dynamic>{...local, ...changes};
    queuedAt = at;
  }
}

/// Servidor simulado.
class _Server {
  Map<String, dynamic> state = <String, dynamic>{};
  DateTime? updatedAt;

  final List<SyncEvent> log = <SyncEvent>[];

  /// Recebe a escrita de um aparelho e aplica a resolução da entidade.
  ConflictResolution receive({
    required String entity,
    required _Device device,
    required DateTime at,
  }) {
    final bool serverChangedSince =
        updatedAt != null && device.queuedAt != null &&
            updatedAt!.isAfter(device.queuedAt!);

    final ConflictResolution resolution = serverChangedSince
        ? ConflictResolver.resolve(
            entity: entity,
            local: device.local,
            remote: state,
          )
        : ConflictResolution(
            strategy: ConflictResolver.strategyFor(entity),
            merged: device.local,
          );

    if (resolution.shouldWrite) {
      state = <String, dynamic>{...state, ...resolution.merged!};
      updatedAt = at;
    }

    log.add(
      SyncEvent(
        id: '${device.name}-${at.microsecondsSinceEpoch}',
        at: at,
        entity: entity,
        entityId: 'doc1',
        outcome: !resolution.shouldWrite
            ? SyncOutcome.discardedLocal
            : resolution.hasConflict
                ? SyncOutcome.merged
                : SyncOutcome.sent,
        strategy: resolution.strategy.name,
        conflictedFields: resolution.conflictedFields,
      ),
    );

    return resolution;
  }
}

void main() {
  group('dois aparelhos editando o cadastro da criança', () {
    late _Device celular;
    late _Device tablet;
    late _Server servidor;

    final DateTime t0 = DateTime(2026, 7, 20, 10, 0);

    setUp(() {
      servidor = _Server()
        ..state = <String, dynamic>{
          'name': 'Manuela',
          'allergies': <String>[],
        }
        ..updatedAt = t0;

      celular = _Device('celular')
        ..local = Map<String, dynamic>.from(servidor.state)
        ..queuedAt = t0;

      tablet = _Device('tablet')
        ..local = Map<String, dynamic>.from(servidor.state)
        ..queuedAt = t0;
    });

    test('edições em campos diferentes convivem', () {
      // Cenário real: mãe corrige o telefone no celular enquanto o pai
      // adiciona o tipo sanguíneo no tablet.
      celular.edit(
        <String, dynamic>{'phone': '11988887777'},
        at: t0.add(const Duration(minutes: 1)),
      );
      tablet.edit(
        <String, dynamic>{'bloodType': 'O+'},
        at: t0.add(const Duration(minutes: 2)),
      );

      servidor.receive(
        entity: 'children',
        device: celular,
        at: t0.add(const Duration(minutes: 3)),
      );
      servidor.receive(
        entity: 'children',
        device: tablet,
        at: t0.add(const Duration(minutes: 4)),
      );

      expect(servidor.state['phone'], '11988887777');
      expect(servidor.state['bloodType'], 'O+');
      expect(servidor.state['name'], 'Manuela');

      // Nada foi descartado.
      expect(
        servidor.log.any((SyncEvent e) => e.outcome.isProblem),
        isFalse,
      );
    });

    test('alergias registradas em aparelhos diferentes se somam', () {
      // O caso que motivou abandonar "última escrita vence". Perder uma
      // alergia na sincronização é o tipo de erro que machuca.
      celular.edit(
        <String, dynamic>{
          'allergies': <String>['amendoim'],
        },
        at: t0.add(const Duration(minutes: 1)),
      );
      tablet.edit(
        <String, dynamic>{
          'allergies': <String>['dipirona'],
        },
        at: t0.add(const Duration(minutes: 2)),
      );

      servidor.receive(
        entity: 'children',
        device: celular,
        at: t0.add(const Duration(minutes: 3)),
      );
      servidor.receive(
        entity: 'children',
        device: tablet,
        at: t0.add(const Duration(minutes: 4)),
      );

      final List<dynamic> finais =
          servidor.state['allergies'] as List<dynamic>;

      expect(finais, containsAll(<String>['amendoim', 'dipirona']));
      expect(finais.length, 2);
    });

    test('mesmo campo divergente registra o conflito', () {
      celular.edit(
        <String, dynamic>{'bloodType': 'O+'},
        at: t0.add(const Duration(minutes: 1)),
      );
      tablet.edit(
        <String, dynamic>{'bloodType': 'A+'},
        at: t0.add(const Duration(minutes: 2)),
      );

      servidor.receive(
        entity: 'children',
        device: celular,
        at: t0.add(const Duration(minutes: 3)),
      );
      final ConflictResolution second = servidor.receive(
        entity: 'children',
        device: tablet,
        at: t0.add(const Duration(minutes: 4)),
      );

      expect(second.hasConflict, isTrue);
      expect(second.conflictedFields, <String>['bloodType']);
      // O histórico guarda o que foi descartado.
      expect(second.discarded!['bloodType'], 'O+');
      expect(
        servidor.log.last.outcome,
        SyncOutcome.merged,
      );
    });
  });

  group('vacina marcada nos dois aparelhos', () {
    test('a data mais antiga prevalece', () {
      // Mãe marca no posto, no dia. Pai marca em casa, três dias depois,
      // olhando a caderneta. A data do posto é a correta.
      final _Server servidor = _Server()
        ..state = <String, dynamic>{
          'vaccineId': 'penta',
          'doseIndex': 1,
          'appliedAt': null,
        }
        ..updatedAt = DateTime(2026, 3, 1);

      final _Device noPosto = _Device('posto')
        ..local = <String, dynamic>{
          'vaccineId': 'penta',
          'doseIndex': 1,
          'appliedAt': '2026-03-01T09:00:00Z',
        }
        ..queuedAt = DateTime(2026, 3, 1);

      final _Device emCasa = _Device('casa')
        ..local = <String, dynamic>{
          'vaccineId': 'penta',
          'doseIndex': 1,
          'appliedAt': '2026-03-04T20:00:00Z',
        }
        ..queuedAt = DateTime(2026, 3, 1);

      servidor.receive(
        entity: 'vaccine_doses',
        device: noPosto,
        at: DateTime(2026, 3, 2),
      );

      final ConflictResolution r = servidor.receive(
        entity: 'vaccine_doses',
        device: emCasa,
        at: DateTime(2026, 3, 5),
      );

      expect(r.shouldWrite, isFalse);
      expect(servidor.state['appliedAt'], '2026-03-01T09:00:00Z');
    });
  });

  group('medições feitas offline nos dois aparelhos', () {
    test('nenhuma é descartada', () {
      // Medição é evento: pesar em casa e no consultório no mesmo dia gera
      // dois registros legítimos.
      final _Server servidor = _Server()..updatedAt = DateTime(2026, 7, 20);

      final _Device casa = _Device('casa')
        ..local = <String, dynamic>{'weightKg': 9.6}
        ..queuedAt = DateTime(2026, 7, 19);

      final _Device consultorio = _Device('consultorio')
        ..local = <String, dynamic>{'weightKg': 9.8}
        ..queuedAt = DateTime(2026, 7, 19);

      final ConflictResolution a = servidor.receive(
        entity: 'growth_records',
        device: casa,
        at: DateTime(2026, 7, 21),
      );
      final ConflictResolution b = servidor.receive(
        entity: 'growth_records',
        device: consultorio,
        at: DateTime(2026, 7, 21, 1),
      );

      expect(a.shouldWrite, isTrue);
      expect(b.shouldWrite, isTrue);
      expect(
        servidor.log.every((SyncEvent e) => !e.outcome.isProblem),
        isTrue,
      );
    });
  });

  group('recuperação após perda de conexão', () {
    test('a fila drena em ordem quando a rede volta', () {
      // Três edições offline no mesmo aparelho, em sequência. Ao reconectar,
      // todas devem chegar, e o estado final refletir a última.
      final _Server servidor = _Server()
        ..state = <String, dynamic>{'name': 'Manuela'}
        ..updatedAt = DateTime(2026, 7, 20, 8);

      final _Device offline = _Device('offline')
        ..local = <String, dynamic>{'name': 'Manuela'}
        ..queuedAt = DateTime(2026, 7, 20, 8);

      final List<Map<String, dynamic>> fila = <Map<String, dynamic>>[
        <String, dynamic>{'phone': '1111'},
        <String, dynamic>{'phone': '2222'},
        <String, dynamic>{'bloodType': 'O+'},
      ];

      for (int i = 0; i < fila.length; i++) {
        offline.edit(
          fila[i],
          at: DateTime(2026, 7, 20, 9, i),
        );
        servidor.receive(
          entity: 'children',
          device: offline,
          at: DateTime(2026, 7, 20, 10, i),
        );
      }

      expect(servidor.state['phone'], '2222');
      expect(servidor.state['bloodType'], 'O+');
      expect(servidor.log.length, 3);
      expect(
        servidor.log.every((SyncEvent e) => !e.outcome.isProblem),
        isTrue,
      );
    });

    test('item que nunca passa é abandonado e registrado', () {
      // Após o limiar, insistir só gasta bateria. O evento fica no histórico
      // para o usuário saber que o dado não subiu.
      final SyncEvent abandoned = SyncEvent(
        id: 'x',
        at: DateTime(2026, 7, 20),
        entity: 'children',
        entityId: 'c1',
        outcome: SyncOutcome.abandoned,
        error: 'PERMISSION_DENIED',
        attempts: 5,
      );

      expect(abandoned.outcome.isProblem, isTrue);
      expect(SyncEvent.fromRow(abandoned.toRow()).attempts, 5);
    });
  });
}
