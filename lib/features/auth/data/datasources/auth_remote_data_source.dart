import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../shared/data/models/app_user_model.dart';
import '../../../../shared/domain/entities/app_user.dart';

/// Acesso direto ao Firebase Auth e ao documento `users/{uid}`.
///
/// O usuario do app e a *juncao* de duas fontes: a credencial (Auth) e o perfil
/// (Firestore). Um login sem documento correspondente e um estado invalido —
/// por isso `_ensureUserDocument` roda em todo caminho de entrada.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  User? get currentAuthUser => _auth.currentUser;

  /// Combina o estado de sessao com o documento de perfil.
  ///
  /// `switchMap` manual: a cada troca de usuario, a escuta do documento antigo
  /// e cancelada — sem isso, sair e entrar com outra conta deixaria dois
  /// listeners ativos e a UI piscaria entre os dois perfis.
  Stream<AppUser?> watchCurrentUser() {
    return _auth.userChanges().asyncExpand<AppUser?>((User? user) {
      if (user == null) return Stream<AppUser?>.value(null);

      return _users.doc(user.uid).snapshots().asyncMap(
        (DocumentSnapshot<Map<String, dynamic>> doc) async {
          if (!doc.exists) {
            // Documento ainda nao criado (primeiro login com provedor social,
            // ou conta antiga). Cria e deixa o proximo snapshot chegar.
            await _ensureUserDocument(user);
            return null;
          }
          return AppUserMapper.fromFirestore(doc).copyWith(
            emailVerified: user.emailVerified,
          );
        },
      );
    });
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User user = credential.user!;
    await _ensureUserDocument(user);
    return _fetchUser(user);
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User user = credential.user!;

    await user.updateDisplayName(name);
    await _createUserDocument(user, name: name);
    await user.sendEmailVerification();

    return _fetchUser(user);
  }

  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters(<String, String>{'prompt': 'select_account'});
      final UserCredential credential = await _auth.signInWithPopup(provider);
      final User user = credential.user!;
      await _ensureUserDocument(user);
      return _fetchUser(user);
    }

    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) {
      throw const AuthException(
        'Login cancelado.',
        code: 'cancelled',
      );
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final UserCredential result = await _auth.signInWithCredential(credential);
    final User user = result.user!;
    await _ensureUserDocument(user);
    return _fetchUser(user);
  }

  Future<void> signOut() async {
    // Remove o token PUSH antes de encerrar a sessão — depois de
    // `_auth.signOut()` não há mais usuário autenticado para gravar no
    // Firestore, e o token continuaria na lista. Num aparelho compartilhado
    // (posto de saúde, secretaria de clínica), isso faria o próximo usuário
    // receber notificação destinada à conta anterior — inclusive avisos
    // clínicos como "novo resultado de exame".
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) await removeDeviceToken(token);
    } catch (_) {
      // Falha ao remover o token não pode impedir o logout — o usuário
      // precisa conseguir sair da conta mesmo sem rede.
    }

    // O logout do Google falha quando a sessao veio de e-mail/senha. Isso nao
    // pode impedir o logout do Firebase, que e o que realmente encerra o acesso.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignorado de proposito
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> sendEmailVerification() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre para continuar.', code: 'no-user');
    }
    await user.sendEmailVerification();
  }

  Future<AppUser> reload() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre para continuar.', code: 'no-user');
    }
    await user.reload();
    return _fetchUser(_auth.currentUser!);
  }

  Future<AppUser> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    String? specialty,
  }) async {
    final User user = _requireUser();

    final Map<String, dynamic> updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      // CRM não entra aqui de propósito — é o dado que a equipe verificou
      // manualmente para liberar prescrição, e não é alterável pelo dono.
      if (specialty != null) 'specialty': specialty,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _users.doc(user.uid).update(updates);

    if (name != null) await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);

    return _fetchUser(user);
  }

  Future<AppUser> completeOnboarding({
    required UserRole role,
    String? crm,
    String? specialty,
  }) async {
    final User user = _requireUser();

    await _users.doc(user.uid).update(<String, dynamic>{
      'role': role.name,
      'crm': crm,
      'specialty': specialty,
      'onboardingDone': true,
      // A verificacao do CRM e manual: o profissional entra como nao verificado
      // e a equipe libera o acesso a prescricao depois de conferir o registro.
      if (role == UserRole.professional) 'professionalVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return _fetchUser(user);
  }

  /// Registra o token deste aparelho para receber notificações.
  ///
  /// Antes escrevia direto em `fcmTokens` no Firestore — o mesmo trabalho
  /// que as Functions `registerDevice`/`unregisterDevice` já faziam, sem
  /// que nada as chamasse. Duas implementações da mesma responsabilidade é
  /// o tipo de duplicação que diverge sem ninguém perceber. Centralizado
  /// aqui: só a Function grava o array, e ela roda como o próprio usuário
  /// autenticado — não há como registrar token em nome de outra conta.
  Future<void> registerDeviceToken(String token) async {
    _requireUser();
    await _functions.httpsCallable('registerDevice').call(<String, dynamic>{
      'token': token,
    });
  }

  Future<void> removeDeviceToken(String token) async {
    if (_auth.currentUser == null) return;
    await _functions.httpsCallable('unregisterDevice').call(<String, dynamic>{
      'token': token,
    });
  }

  /// Exclui a conta. Reautentica antes: o Firebase exige credencial recente
  /// para operacoes destrutivas.
  Future<void> deleteAccount({required String password}) async {
    final User user = _requireUser();
    final String email = user.email ?? '';

    if (email.isNotEmpty && password.isNotEmpty) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    }

    // O documento e as subcollections sao removidos pela Cloud Function
    // `onUserDeleted`, que roda com privilegio de admin.
    await user.delete();
  }

  // ------------------------------------------------------------ Auxiliares

  User _requireUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Entre para continuar.', code: 'no-user');
    }
    return user;
  }

  Future<AppUser> _fetchUser(User user) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _users.doc(user.uid).get();

    if (!doc.exists) {
      await _ensureUserDocument(user);
      final DocumentSnapshot<Map<String, dynamic>> retry =
          await _users.doc(user.uid).get();
      return AppUserMapper.fromFirestore(retry)
          .copyWith(emailVerified: user.emailVerified);
    }

    return AppUserMapper.fromFirestore(doc)
        .copyWith(emailVerified: user.emailVerified);
  }

  Future<void> _ensureUserDocument(User user) async {
    final DocumentReference<Map<String, dynamic>> ref = _users.doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    if (doc.exists) return;
    await _createUserDocument(user, name: user.displayName ?? '');
  }

  Future<void> _createUserDocument(User user, {required String name}) async {
    final AppUser initial = AppUser.initial(
      uid: user.uid,
      email: user.email ?? '',
      name: name.isEmpty ? (user.email?.split('@').first ?? 'Usuario') : name,
      photoUrl: user.photoURL,
    );
    await _users.doc(user.uid).set(
          AppUserMapper.toCreateMap(initial),
          SetOptions(merge: true),
        );
  }
}
