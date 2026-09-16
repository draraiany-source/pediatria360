import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Eventos de produto do Pediatria 360.
///
/// Nomes ficam centralizados aqui para que o funil no console nao vire uma
/// colecao de strings soltas escritas de formas diferentes em cada tela.
class AnalyticsEvent {
  const AnalyticsEvent._();

  static const String signUp = 'sign_up';
  static const String login = 'login';
  static const String logout = 'logout';
  static const String childCreated = 'child_created';
  static const String growthRecorded = 'growth_recorded';
  static const String vaccineMarked = 'vaccine_marked';
  static const String aiMessageSent = 'ai_message_sent';
  static const String protocolOpened = 'protocol_opened';
  static const String calculatorUsed = 'calculator_used';
  static const String lessonStarted = 'lesson_started';
  static const String lessonCompleted = 'lesson_completed';
  static const String videoPlayed = 'video_played';
  static const String productViewed = 'view_item';
  static const String addedToCart = 'add_to_cart';
  static const String checkoutStarted = 'begin_checkout';
  static const String purchase = 'purchase';
  static const String subscriptionStarted = 'subscription_started';
  static const String appointmentBooked = 'appointment_booked';
  static const String badgeEarned = 'badge_earned';
  static const String streakKept = 'streak_kept';
  static const String searchPerformed = 'search';
}

/// Camada fina sobre o Firebase Analytics.
///
/// Em modo debug os eventos sao apenas registrados no console — evita poluir
/// o funil de producao com dados de desenvolvimento.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    if (kDebugMode) {
      debugPrint('[analytics] $name ${parameters ?? ''}');
      return;
    }
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUser({
    required String? uid,
    String? role,
    String? plan,
  }) async {
    await _analytics.setUserId(id: uid);
    if (role != null) {
      await _analytics.setUserProperty(name: 'role', value: role);
    }
    if (plan != null) {
      await _analytics.setUserProperty(name: 'plan', value: plan);
    }
  }

  Future<void> logScreen(String screenName) async {
    if (kDebugMode) return;
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logSearch(String term, {String? area}) => logEvent(
        AnalyticsEvent.searchPerformed,
        <String, Object>{
          'search_term': term,
          if (area != null) 'area': area,
        },
      );

  Future<void> logPurchase({
    required String orderId,
    required double value,
    String currency = 'BRL',
    String? coupon,
  }) =>
      logEvent(
        AnalyticsEvent.purchase,
        <String, Object>{
          'transaction_id': orderId,
          'value': value,
          'currency': currency,
          if (coupon != null) 'coupon': coupon,
        },
      );

  Future<void> setAnalyticsEnabled({required bool enabled}) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}
