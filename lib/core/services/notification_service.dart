import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_logger.dart';

/// Handler de mensagens recebidas com o app encerrado.
///
/// Precisa ser uma funcao de topo (requisito do plugin) e nao pode tocar em
/// nenhum estado do app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('push em background: ${message.messageId}', tag: 'fcm');
}

/// Notificacoes push (FCM) e locais.
///
/// O app usa push para tres coisas: lembrete de vacina, resposta de consulta
/// e resposta longa da IA. Cada payload traz `route`, que o `NotificationRouter`
/// converte em navegacao — nenhuma notificacao termina em "abriu a home".
class NotificationService {
  NotificationService(this._messaging, this._local);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  final StreamController<String> _routeController =
      StreamController<String>.broadcast();

  /// Rotas solicitadas por toque em notificacao.
  Stream<String> get onNotificationRoute => _routeController.stream;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'p360_default',
    'Avisos do Pediatria 360',
    description: 'Lembretes de vacina, consultas e respostas da IA.',
    importance: Importance.high,
  );

  static Future<NotificationService> init() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final FlutterLocalNotificationsPlugin local =
        FlutterLocalNotificationsPlugin();

    final NotificationService service = NotificationService(messaging, local);
    await service._setup();
    return service;
  }

  Future<void> _setup() async {
    if (!kIsWeb) {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final String? payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _emitRoute(payload);
          }
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final RemoteMessage? initial = await _messaging.getInitialMessage();
    if (initial != null) _onMessageOpened(initial);
  }

  /// Pede permissao. Chamado depois do login, com contexto explicando o
  /// motivo — nunca no primeiro segundo de uso.
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } catch (error, stack) {
      await AppLogger.error(error, stack, reason: 'fcm.getToken');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);
  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  Future<void> deleteToken() => _messaging.deleteToken();

  void _onForegroundMessage(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification == null || kIsWeb) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String? ?? '',
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final String? route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) _emitRoute(route);
  }

  void _emitRoute(String route) {
    if (!_routeController.isClosed) _routeController.add(route);
  }

  /// Agenda um lembrete local (usado para vacinas e doses de medicacao).
  Future<void> scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? route,
  }) async {
    if (kIsWeb) return;
    // `zonedSchedule` exige timezone; para manter o bootstrap simples usamos
    // `periodicallyShow`-free abordagem: a Cloud Function `scheduleVaccine`
    // dispara o push no horario. Aqui guardamos apenas o lembrete imediato
    // quando o horario ja passou.
    if (when.isAfter(DateTime.now())) return;
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: route ?? '',
    );
  }

  /// Payload cru, util para depuracao no dashboard admin.
  static String encodePayload(Map<String, dynamic> data) => jsonEncode(data);

  Future<void> dispose() => _routeController.close();
}
