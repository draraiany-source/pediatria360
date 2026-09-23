/// Detecta acessos bloqueados repetidos no mesmo uid (janela deslizante).
class BlockedAccessTracker {
  BlockedAccessTracker({
    this.window = const Duration(minutes: 5),
    this.threshold = 3,
  });

  final Duration window;
  final int threshold;

  final Map<String, List<DateTime>> _eventsByUid = <String, List<DateTime>>{};

  /// Registra tentativa bloqueada; retorna true se atingiu [threshold] na janela.
  bool record(String uid, DateTime now) {
    final List<DateTime> events =
        _eventsByUid.putIfAbsent(uid, () => <DateTime>[]);
    events.add(now);
    events.removeWhere((DateTime t) => now.difference(t) > window);
    return events.length >= threshold;
  }

  void clear() => _eventsByUid.clear();
}
