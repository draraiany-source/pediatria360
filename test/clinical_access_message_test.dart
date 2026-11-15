import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/error/failures.dart';
import 'package:pediatria360/core/utils/clinical_access.dart';

void main() {
  group('clinicalLoadErrorMessage', () {
    test('sessão de demonstração explica que falta login, sem culpar a regra',
        () {
      final String msg =
          clinicalLoadErrorMessage(guestSessionFailure('Os pacientes reais'));
      expect(msg, contains('modo demonstração'));
      expect(msg, contains('Os pacientes reais'));
      expect(msg, isNot(contains('servidor recusou')));
    });

    test('recusa do app mantém o motivo (autorização do responsável)', () {
      const PermissionFailure failure = PermissionFailure(
        'O responsável ainda não autorizou o acesso ao prontuário desta '
        'criança para você.',
      );
      expect(clinicalLoadErrorMessage(failure), failure.message);
    });

    test('recusa das regras do Firestore orienta conta, registro e vínculo',
        () {
      final FirebaseException denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      final String msg = clinicalLoadErrorMessage(denied);
      expect(msg, contains('servidor recusou'));
      expect(msg, contains('vínculo com a clínica'));
    });

    test('índice ausente continua com a mensagem própria', () {
      final FirebaseException index = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'The query requires an index.',
      );
      expect(clinicalLoadErrorMessage(index), contains('Índice do Firestore'));
    });
  });
}
