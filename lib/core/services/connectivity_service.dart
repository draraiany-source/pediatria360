import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de conectividade do aparelho.
///
/// Fonte unica para a decisao "buscar na rede ou servir cache" e para o gatilho
/// de sincronizacao da fila offline.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
    unawaited(_bootstrap());
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  /// `true` quando ha alguma interface de rede ativa.
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Emite a cada transicao online/offline.
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> _bootstrap() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    _onChanged(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final bool online = results.any(
      (ConnectivityResult r) => r != ConnectivityResult.none,
    );
    if (online == _isOnline) return;
    _isOnline = online;
    if (!_controller.isClosed) _controller.add(online);
  }

  /// Consulta pontual, util antes de uma escrita critica.
  Future<bool> check() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    _onChanged(results);
    return _isOnline;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
