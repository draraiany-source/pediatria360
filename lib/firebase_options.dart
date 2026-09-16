// File generated from Firebase SDK configs for project pediatria360-app.
// Android / iOS / Web app IDs come from `firebase apps:sdkconfig`.
// Do not replace with placeholders. Re-run flutterfire configure if apps change.
//
//   flutterfire configure --project=pediatria360-app

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Opcoes do Firebase por plataforma.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => web,
      TargetPlatform.linux => web,
      TargetPlatform.fuchsia => throw UnsupportedError(
          'Pediatria 360 nao tem build para Fuchsia.',
        ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA3W3184wmheesWLGaPQrGy7oasHMKNuEA',
    appId: '1:497881626985:android:2a9a97d655e2b9ebe065f8',
    messagingSenderId: '497881626985',
    projectId: 'pediatria360-app',
    storageBucket: 'pediatria360-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC_GExbzCzaNszbYNl9Gs06MPSOy46fDjc',
    appId: '1:497881626985:ios:f5b38d41a25c1f7ae065f8',
    messagingSenderId: '497881626985',
    projectId: 'pediatria360-app',
    storageBucket: 'pediatria360-app.firebasestorage.app',
    iosBundleId: 'app.pediatria360',
  );

  /// macOS reutiliza o app iOS (mesmo bundle `app.pediatria360`) ate existir
  /// registro dedicado no Console.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC_GExbzCzaNszbYNl9Gs06MPSOy46fDjc',
    appId: '1:497881626985:ios:f5b38d41a25c1f7ae065f8',
    messagingSenderId: '497881626985',
    projectId: 'pediatria360-app',
    storageBucket: 'pediatria360-app.firebasestorage.app',
    iosBundleId: 'app.pediatria360',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgSuNW8kQQ0A1J6k_w6a-7uj9v71SJJeQ',
    appId: '1:497881626985:web:13f295d178dd8347e065f8',
    messagingSenderId: '497881626985',
    projectId: 'pediatria360-app',
    authDomain: 'pediatria360-app.firebaseapp.com',
    storageBucket: 'pediatria360-app.firebasestorage.app',
  );

  /// `true` enquanto as chaves de exemplo nao forem substituidas.
  static bool get isPlaceholder =>
      currentPlatform.apiKey.startsWith('SUBSTITUA');
}
