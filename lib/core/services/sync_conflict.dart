import 'dart:math' as math;

/// Resolução de conflitos de sincronização.
///
/// ## O problema com "última escrita vence"
///
/// A política anterior descartava a escrita local quando o servidor tinha
/// versão mais nova. Isso é simples e errado: o dado do usuário some sem aviso.
/// Uma mãe que registra o peso no celular e no tablet perde um dos registros —
/// e nunca fica sabendo.
///
/// Pior: o critério era o relógio do aparelho. Celular com hora errada
/// sobrescreve dado correto.
///
/// ## A política adotada aqui
///
/// Cada tipo de dado tem a resolução que faz sentido para ele:
///
/// | Entidade   | Estratégia            | Por quê |
/// |------------|-----------------------|---------|
/// | Medições   | Mantém as duas        | Medição é evento, não estado. Duas medições no mesmo dia são dois fatos. |
/// | Vacinas    | Mantém a data anterior | Quem registrou mais perto do evento tende a acertar. |
/// | Cadastro   | Mescla por campo      | Editar telefone no celular e alergia no tablet não é conflito. |
///
/// Conflito de verdade — mesmo campo, valores diferentes — é **registrado** e
/// resolvido pelo mais recente, mas fica no histórico para o usuário poder
/// conferir.
enum ConflictStrategy {
  /// Ambas as versões coexistem. Para dados que são eventos, não estados.
  keepBoth,

  /// Mescla campo a campo; só há conflito se o mesmo campo divergir.
  mergeFields,

  /// Mantém o valor mais antigo — usado quando o primeiro registro tende a
  /// ser o mais fiel ao fato.
  preferEarliest,

  /// Último a escrever vence. Último recurso.
  lastWriteWins;

  String get label => switch (this) {
        ConflictStrategy.keepBoth => 'Manter ambos',
        ConflictStrategy.mergeFields => 'Mesclar campos',
        ConflictStrategy.preferEarliest => 'Manter o mais antigo',
        ConflictStrategy.lastWriteWins => 'Manter o mais recente',
      };
}

/// Resultado de uma resolução.
class ConflictResolution {
  const ConflictResolution({
    required this.strategy,
    required this.merged,
    this.conflictedFields = const <String>[],
    this.discarded,
  });

  final ConflictStrategy strategy;

  /// Documento final a ser gravado. `null` significa "não escrever" — a
  /// versão do servidor prevalece inteira.
  final Map<String, dynamic>? merged;

  /// Campos em que houve divergência real. Alimenta o histórico.
  final List<String> conflictedFields;

  /// O que foi descartado, quando algo foi. Guardado para o usuário conferir.
  final Map<String, dynamic>? discarded;

  bool get hasConflict => conflictedFields.isNotEmpty;
  bool get shouldWrite => merged != null;
}

/// Motor de resolução.
class ConflictResolver {
  const ConflictResolver._();

  /// Campos que o servidor controla e o cliente nunca sobrescreve.
  static const Set<String> _serverOwned = <String>{
    'createdAt',
    'updatedAt',
    'ownerId',
    'searchTerms',
    'currentVersion',
  };

  /// Estratégia de cada entidade.
  static ConflictStrategy strategyFor(String entity) => switch (entity) {
        'growth_records' => ConflictStrategy.keepBoth,
        'vaccine_doses' => ConflictStrategy.preferEarliest,
        'children' => ConflictStrategy.mergeFields,
        _ => ConflictStrategy.lastWriteWins,
      };

  /// Resolve o conflito entre a versão local e a do servidor.
  static ConflictResolution resolve({
    required String entity,
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final ConflictStrategy strategy = strategyFor(entity);

    return switch (strategy) {
      // Medição é evento: duas no mesmo dia são dois fatos, não uma
      // contradição. A escrita local segue com id próprio.
      ConflictStrategy.keepBoth => ConflictResolution(
          strategy: strategy,
          merged: local,
        ),

      ConflictStrategy.preferEarliest =>
        _preferEarliest(strategy, local, remote),

      ConflictStrategy.mergeFields => _mergeFields(strategy, local, remote),

      ConflictStrategy.lastWriteWins => ConflictResolution(
          strategy: strategy,
          merged: local,
          discarded: remote,
        ),
    };
  }

  /// Vacina: se as duas versões marcam aplicada, a data mais antiga vence.
  ///
  /// Quem registrou logo depois da aplicação tende a lembrar melhor que quem
  /// registrou semanas depois olhando a caderneta.
  static ConflictResolution _preferEarliest(
    ConflictStrategy strategy,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final DateTime? localApplied = _date(local['appliedAt']);
    final DateTime? remoteApplied = _date(remote['appliedAt']);

    // Só um dos lados marcou: não há conflito, a marcação vence.
    if (localApplied == null && remoteApplied != null) {
      return ConflictResolution(strategy: strategy, merged: null);
    }
    if (localApplied != null && remoteApplied == null) {
      return ConflictResolution(strategy: strategy, merged: local);
    }
    if (localApplied == null && remoteApplied == null) {
      return ConflictResolution(strategy: strategy, merged: local);
    }

    if (remoteApplied!.isBefore(localApplied!)) {
      return ConflictResolution(
        strategy: strategy,
        merged: null,
        conflictedFields: localApplied == remoteApplied
            ? const <String>[]
            : const <String>['appliedAt'],
        discarded: local,
      );
    }

    return ConflictResolution(
      strategy: strategy,
      merged: local,
      conflictedFields: localApplied == remoteApplied
          ? const <String>[]
          : const <String>['appliedAt'],
      discarded: remote,
    );
  }

  /// Cadastro: mescla campo a campo.
  ///
  /// Editar o telefone no celular e a alergia no tablet não é conflito — são
  /// duas edições compatíveis. Conflito é o mesmo campo com valores
  /// diferentes, e só esse caso precisa de decisão.
  static ConflictResolution _mergeFields(
    ConflictStrategy strategy,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final Map<String, dynamic> merged = Map<String, dynamic>.from(remote);
    final List<String> conflicts = <String>[];

    for (final MapEntry<String, dynamic> entry in local.entries) {
      if (_serverOwned.contains(entry.key)) continue;

      final dynamic remoteValue = remote[entry.key];

      // Campo que só existe localmente: adiciona sem drama.
      if (!remote.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
        continue;
      }

      if (_equal(entry.value, remoteValue)) continue;

      // Listas de texto — alergias, condições — são união, não substituição.
      // Perder uma alergia numa mesclagem é o tipo de erro que machuca.
      if (entry.value is List && remoteValue is List) {
        final Set<dynamic> union = <dynamic>{
          ...remoteValue,
          ...entry.value as List<dynamic>,
        };
        merged[entry.key] = union.toList(growable: false);
        continue;
      }

      // Divergência real: o local vence, mas fica registrado.
      merged[entry.key] = entry.value;
      conflicts.add(entry.key);
    }

    return ConflictResolution(
      strategy: strategy,
      merged: merged,
      conflictedFields: conflicts,
      discarded: conflicts.isEmpty
          ? null
          : <String, dynamic>{
              for (final String field in conflicts) field: remote[field],
            },
    );
  }

  static bool _equal(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  static DateTime? _date(Object? value) => switch (value) {
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };
}

/// Espera entre tentativas de envio.
///
/// ## Por que exponencial com ruído
///
/// Repetir a cada 5 segundos contra um servidor fora do ar transforma o app em
/// gerador de tráfego inútil e queima bateria. A espera cresce a cada falha.
///
/// O ruído aleatório evita o efeito manada: sem ele, mil aparelhos que caíram
/// na mesma queda de rede voltam exatamente juntos e derrubam o servidor de
/// novo assim que ele levanta.
class SyncBackoff {
  const SyncBackoff._();

  static const Duration base = Duration(seconds: 4);
  static const Duration ceiling = Duration(minutes: 30);

  /// Espera antes da próxima tentativa.
  static Duration delayFor(int attempts, {math.Random? random}) {
    if (attempts <= 0) return Duration.zero;

    // 4s, 8s, 16s, 32s, 64s...
    final int exponential =
        base.inMilliseconds * math.pow(2, attempts - 1).toInt();

    final int capped = math.min(exponential, ceiling.inMilliseconds);

    // Ruído de até 25% para baixo — nunca aumenta a espera além do teto.
    final double jitter =
        1 - ((random ?? math.Random()).nextDouble() * 0.25);

    return Duration(milliseconds: (capped * jitter).round());
  }

  /// `true` se já passou tempo suficiente desde a última falha.
  static bool isReady({
    required int attempts,
    required DateTime? lastAttemptAt,
    DateTime? now,
    math.Random? random,
  }) {
    if (attempts == 0 || lastAttemptAt == null) return true;

    final DateTime current = now ?? DateTime.now();
    final Duration waited = current.difference(lastAttemptAt);

    return waited >= delayFor(attempts, random: random);
  }
}

/// Um evento no histórico de sincronização.
///
/// Existe para responder à pergunta que o usuário faz quando algo some:
/// *"o que aconteceu com o registro que eu fiz ontem?"*. Sem histórico, a
/// resposta honesta é "não sei".
class SyncEvent {
  const SyncEvent({
    required this.id,
    required this.at,
    required this.entity,
    required this.entityId,
    required this.outcome,
    this.strategy,
    this.conflictedFields = const <String>[],
    this.error,
    this.attempts = 0,
  });

  factory SyncEvent.fromRow(Map<String, Object?> row) => SyncEvent(
        id: row['id']! as String,
        at: DateTime.fromMillisecondsSinceEpoch(
          row['at']! as int,
          isUtc: true,
        ).toLocal(),
        entity: row['entity']! as String,
        entityId: row['entity_id']! as String,
        outcome: SyncOutcome.fromName(row['outcome'] as String?),
        strategy: row['strategy'] as String?,
        conflictedFields: ((row['conflicted_fields'] as String?) ?? '')
            .split(',')
            .where((String s) => s.isNotEmpty)
            .toList(growable: false),
        error: row['error'] as String?,
        attempts: (row['attempts'] as int?) ?? 0,
      );

  final String id;
  final DateTime at;
  final String entity;
  final String entityId;
  final SyncOutcome outcome;
  final String? strategy;
  final List<String> conflictedFields;
  final String? error;
  final int attempts;

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'at': at.toUtc().millisecondsSinceEpoch,
        'entity': entity,
        'entity_id': entityId,
        'outcome': outcome.name,
        'strategy': strategy,
        'conflicted_fields': conflictedFields.join(','),
        'error': error,
        'attempts': attempts,
      };
}

enum SyncOutcome {
  sent,
  merged,
  discardedLocal,
  failed,
  abandoned;

  static SyncOutcome fromName(String? value) => SyncOutcome.values.firstWhere(
        (SyncOutcome o) => o.name == value,
        orElse: () => SyncOutcome.failed,
      );

  String get label => switch (this) {
        SyncOutcome.sent => 'Enviado',
        SyncOutcome.merged => 'Mesclado com a versão do servidor',
        SyncOutcome.discardedLocal => 'Versão local descartada',
        SyncOutcome.failed => 'Falhou',
        SyncOutcome.abandoned => 'Abandonado após várias tentativas',
      };

  bool get isProblem =>
      this == SyncOutcome.failed ||
      this == SyncOutcome.abandoned ||
      this == SyncOutcome.discardedLocal;
}
