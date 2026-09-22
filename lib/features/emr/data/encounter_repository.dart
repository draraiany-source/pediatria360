import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/models/visit_summary_model.dart';
import '../../../shared/domain/entities/clinical_record.dart';
import '../../../shared/domain/entities/encounter.dart';
import '../../../shared/domain/entities/visit_summary.dart';

/// Acesso ao prontuário eletrônico.
///
/// ## A regra que organiza tudo aqui
///
/// **Rascunho é editável. Assinado, não.**
///
/// Depois de assinado, o atendimento é imutável. Corrigir gera um novo
/// atendimento marcado como retificação, vinculado ao original, que continua
/// legível. É o princípio do prontuário em papel — rasura invalida — e é o que
/// protege paciente e profissional quando algo é questionado.
///
/// A imutabilidade é imposta em três camadas: aqui, nas regras do Firestore e
/// na Function que assina. Nenhuma sozinha bastaria.
class EncounterRepository {
  EncounterRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _encounters =>
      _firestore.collection('encounters');

  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection('clinical_documents');

  CollectionReference<Map<String, dynamic>> get _visitSummaries =>
      _firestore.collection('visit_summaries');

  // ------------------------------------------------------------- Leitura

  /// Atendimentos de um paciente, do mais recente para o mais antigo.
  Stream<List<Encounter>> watchPatientEncounters(String patientId) =>
      _encounters
          .where('patientId', isEqualTo: patientId)
          .orderBy('startedAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(_fromFirestore).toList(growable: false),
          );

  /// Atendimentos que o profissional conduziu.
  Stream<List<Encounter>> watchProfessionalEncounters(String professionalId) =>
      _encounters
          .where('professionalId', isEqualTo: professionalId)
          .orderBy('startedAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(_fromFirestore).toList(growable: false),
          );

  Stream<Encounter?> watchEncounter(String encounterId) =>
      _encounters.doc(encounterId).snapshots().map(
            (DocumentSnapshot<Map<String, dynamic>> d) =>
                d.exists ? _fromFirestore(d) : null,
          );

  /// Rascunho em aberto deste profissional para este paciente.
  ///
  /// Evita que uma consulta interrompida gere dois registros paralelos quando
  /// o médico volta à tela.
  Future<Result<Encounter?>> openDraft({
    required String patientId,
    required String professionalId,
  }) =>
      guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _encounters
            .where('patientId', isEqualTo: patientId)
            .where('professionalId', isEqualTo: professionalId)
            .where('status', isEqualTo: EncounterStatus.draft.name)
            .orderBy('startedAt', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) return null;
        return _fromFirestore(snapshot.docs.first);
      });

  // ------------------------------------------------------------- Escrita

  /// Cria um atendimento em rascunho.
  Future<Result<Encounter>> create({
    required String patientId,
    required String professionalId,
    required String professionalName,
    required EncounterType type,
    String? professionalCrm,
    String? patientName,
    DateTime? patientBirthDate,
    String? appointmentId,
    String? clinicId,
  }) =>
      guard(() async {
        final String id = _uuid.v4();
        final DateTime now = DateTime.now();

        await _encounters.doc(id).set(<String, dynamic>{
          'patientId': patientId,
          'professionalId': professionalId,
          'professionalName': professionalName,
          'professionalCrm': professionalCrm,
          'patientName': patientName,
          'patientBirthDate': patientBirthDate == null
              ? null
              : Timestamp.fromDate(patientBirthDate),
          'type': type.name,
          'status': EncounterStatus.draft.name,
          'startedAt': FieldValue.serverTimestamp(),
          'appointmentId': appointmentId,
          if (clinicId != null && clinicId.isNotEmpty) 'clinicId': clinicId,
          'anamnesis': const Anamnesis().toMap(),
          'vitals': const VitalSigns().toMap(),
          'exam': const PhysicalExam().toMap(),
          'diagnoses': <Map<String, dynamic>>[],
          'assessment': '',
          'plan': '',
          'procedures': <Map<String, dynamic>>[],
          'attachmentIds': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Concede a leitura do resumo de segurança da criança (nome, idade,
        // alergia) — não bloqueia a criação do atendimento se falhar. O
        // atendimento em si já está gravado e é o que importa; a concessão é
        // um extra de UX (mostrar o card de segurança na linha do tempo),
        // não um requisito para atender.
        unawaited(
          _functions
              .httpsCallable('grantChildSummaryAccess')
              .call(<String, dynamic>{'childId': patientId})
              .then((_) {}, onError: (_) {}),
        );

        return Encounter(
          id: id,
          patientId: patientId,
          professionalId: professionalId,
          professionalName: professionalName,
          professionalCrm: professionalCrm,
          patientName: patientName,
          patientBirthDate: patientBirthDate,
          type: type,
          status: EncounterStatus.draft,
          startedAt: now,
          appointmentId: appointmentId,
        );
      });

  /// Salva alterações parciais do rascunho.
  ///
  /// Escrita por seção, não do documento inteiro: o médico preenche a anamnese,
  /// examina, volta e digita o exame. Reescrever tudo a cada passo criaria
  /// corrida entre abas abertas.
  Future<Result<void>> updateDraft({
    required String encounterId,
    Anamnesis? anamnesis,
    VitalSigns? vitals,
    PhysicalExam? exam,
    List<Diagnosis>? diagnoses,
    String? assessment,
    String? plan,
    List<ProcedureRecord>? procedures,
  }) =>
      guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _encounters.doc(encounterId).get();

        if (!doc.exists) throw StateError('Atendimento não encontrado.');

        final String status =
            (doc.data()?['status'] as String?) ?? EncounterStatus.draft.name;

        if (status != EncounterStatus.draft.name) {
          throw StateError(
            'Este atendimento já foi assinado. Para corrigir, emita uma '
            'retificação.',
          );
        }

        await _encounters.doc(encounterId).update(<String, dynamic>{
          if (anamnesis != null) 'anamnesis': anamnesis.toMap(),
          if (vitals != null) 'vitals': vitals.toMap(),
          if (exam != null) 'exam': exam.toMap(),
          if (diagnoses != null)
            'diagnoses':
                diagnoses.map((Diagnosis d) => d.toMap()).toList(growable: false),
          if (assessment != null) 'assessment': assessment,
          if (plan != null) 'plan': plan,
          if (procedures != null)
            'procedures': procedures
                .map((ProcedureRecord p) => p.toMap())
                .toList(growable: false),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Assina o atendimento.
  ///
  /// A assinatura passa por Cloud Function: o hash precisa ser calculado sobre
  /// o estado do servidor, não sobre o que o cliente diz que gravou.
  Future<Result<String>> sign(String encounterId) => guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('signEncounter')
            .call(<String, dynamic>{'encounterId': encounterId});

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        return (data['signatureHash'] as String?) ?? '';
      });

  /// Cria uma retificação de um atendimento já assinado.
  ///
  /// O original permanece intacto e legível. A retificação nasce como rascunho
  /// com o conteúdo copiado, para o médico corrigir o que precisa.
  Future<Result<Encounter>> amend({
    required String originalId,
    required String reason,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('amendEncounter')
            .call(<String, dynamic>{
          'encounterId': originalId,
          'reason': reason,
        });

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        final String newId = (data['encounterId'] as String?) ?? '';
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _encounters.doc(newId).get();

        return _fromFirestore(doc);
      });

  // ---------------------------------------------------------- Documentos

  Stream<List<ClinicalDocument>> watchDocuments(String encounterId) =>
      _documents
          .where('encounterId', isEqualTo: encounterId)
          .orderBy('issuedAt', descending: true)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(_documentFrom).toList(growable: false),
          );

  Stream<List<ClinicalDocument>> watchPatientDocuments(String patientId) =>
      _documents
          .where('patientId', isEqualTo: patientId)
          .orderBy('issuedAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(_documentFrom).toList(growable: false),
          );

  /// Documentos emitidos pelo profissional ainda sem assinatura.
  Future<List<ClinicalDocument>> fetchUnsignedDocumentsForProfessional(
    String professionalId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _documents
        .where('professionalId', isEqualTo: professionalId)
        .limit(150)
        .get();
    return snap.docs
        .map(_documentFrom)
        .where(
          (ClinicalDocument d) => !d.isSigned && !d.cancelled,
        )
        .toList(growable: false);
  }

  /// Exames que exigem revisão clínica (fora da faixa ou marcados).
  Future<List<LabResult>> fetchPendingLabsForPatients(
    List<String> patientIds,
  ) async {
    final List<LabResult> out = <LabResult>[];
    final Iterable<String> ids = patientIds.take(25);
    for (final String patientId in ids) {
      final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('lab_results')
          .where('patientId', isEqualTo: patientId)
          .orderBy('collectedAt', descending: true)
          .limit(40)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final Map<String, dynamic> m = d.data();
        final LabResult lab = LabResult(
          id: d.id,
          patientId: (m['patientId'] as String?) ?? '',
          analyte: (m['analyte'] as String?) ?? '',
          collectedAt:
              (m['collectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          value: (m['value'] as num?)?.toDouble(),
          textValue: m['textValue'] as String?,
          unit: m['unit'] as String?,
          referenceLow: (m['referenceLow'] as num?)?.toDouble(),
          referenceHigh: (m['referenceHigh'] as num?)?.toDouble(),
          laboratory: m['laboratory'] as String?,
          panel: m['panel'] as String?,
          encounterId: m['encounterId'] as String?,
          attachmentUrl: m['attachmentUrl'] as String?,
          note: m['note'] as String?,
        );
        if (_labNeedsReview(lab)) out.add(lab);
      }
    }
    return out;
  }

  static bool _labNeedsReview(LabResult lab) {
    if (lab.isOutOfRange) return true;
    final String? note = lab.note?.toLowerCase();
    return note != null &&
        (note.contains('pendente') || note.contains('revisar'));
  }

  /// Emite receita, atestado, encaminhamento, relatório ou alta.
  ///
  /// Passa por Function: o código de verificação e o hash precisam ser
  /// gerados no servidor para valerem como conferência de autenticidade.
  Future<Result<ClinicalDocument>> issueDocument({
    required String encounterId,
    required ClinicalDocumentType type,
    required String content,
    List<PrescriptionItem> items = const <PrescriptionItem>[],
    DateTime? validUntil,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('issueClinicalDocument')
            .call(<String, dynamic>{
          'encounterId': encounterId,
          'type': type.name,
          'content': content,
          'items': items
              .map((PrescriptionItem i) => i.toMap())
              .toList(growable: false),
          if (validUntil != null)
            'validUntil': validUntil.toUtc().toIso8601String(),
        });

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _documents.doc(data['documentId'] as String).get();

        return _documentFrom(doc);
      });

  Future<Result<void>> cancelDocument({
    required String documentId,
    required String reason,
  }) =>
      guard(() async {
        await _functions
            .httpsCallable('cancelClinicalDocument')
            .call(<String, dynamic>{
          'documentId': documentId,
          'reason': reason,
        });
      });

  // -------------------------------------------------------------- Exames

  Stream<List<LabResult>> watchLabResults(String patientId) => _firestore
      .collection('lab_results')
      .where('patientId', isEqualTo: patientId)
      .orderBy('collectedAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) {
                final Map<String, dynamic> m = d.data();
                return LabResult(
                  id: d.id,
                  patientId: (m['patientId'] as String?) ?? '',
                  analyte: (m['analyte'] as String?) ?? '',
                  collectedAt:
                      (m['collectedAt'] as Timestamp?)?.toDate() ??
                          DateTime.now(),
                  value: (m['value'] as num?)?.toDouble(),
                  textValue: m['textValue'] as String?,
                  unit: m['unit'] as String?,
                  referenceLow: (m['referenceLow'] as num?)?.toDouble(),
                  referenceHigh: (m['referenceHigh'] as num?)?.toDouble(),
                  laboratory: m['laboratory'] as String?,
                  panel: m['panel'] as String?,
                  encounterId: m['encounterId'] as String?,
                  attachmentUrl: m['attachmentUrl'] as String?,
                  note: m['note'] as String?,
                );
              },
            )
            .toList(growable: false),
      );

  /// Registra resultados laboratoriais.
  ///
  /// Aceita lote porque um hemograma chega com quinze analitos — salvar um a um
  /// geraria quinze escritas e um estado intermediário incoerente na tela.
  Future<Result<void>> saveLabResults({
    required String patientId,
    required String professionalId,
    required List<LabResult> results,
    String? encounterId,
  }) =>
      guard(() async {
        final WriteBatch batch = _firestore.batch();

        for (final LabResult r in results) {
          batch.set(
            _firestore.collection('lab_results').doc(),
            <String, dynamic>{
              'patientId': patientId,
              'professionalId': professionalId,
              'analyte': r.analyte,
              'collectedAt': Timestamp.fromDate(r.collectedAt),
              'value': r.value,
              'textValue': r.textValue,
              'unit': r.unit,
              'referenceLow': r.referenceLow,
              'referenceHigh': r.referenceHigh,
              'laboratory': r.laboratory,
              'panel': r.panel,
              'encounterId': encounterId ?? r.encounterId,
              'attachmentUrl': r.attachmentUrl,
              'note': r.note,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }

        await batch.commit();
      });

  // ------------------------------------------------------------ Conversão

  static Encounter _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? const <String, dynamic>{};

    return Encounter(
      id: doc.id,
      patientId: (d['patientId'] as String?) ?? '',
      professionalId: (d['professionalId'] as String?) ?? '',
      professionalName: (d['professionalName'] as String?) ?? '',
      professionalCrm: d['professionalCrm'] as String?,
      patientName: d['patientName'] as String?,
      patientBirthDate: (d['patientBirthDate'] as Timestamp?)?.toDate(),
      type: EncounterType.fromName(d['type'] as String?),
      status: EncounterStatus.fromName(d['status'] as String?),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      anamnesis: Anamnesis.fromMap(
        Map<String, dynamic>.from(
          (d['anamnesis'] as Map<dynamic, dynamic>?) ??
              const <dynamic, dynamic>{},
        ),
      ),
      vitals: VitalSigns.fromMap(
        Map<String, dynamic>.from(
          (d['vitals'] as Map<dynamic, dynamic>?) ?? const <dynamic, dynamic>{},
        ),
      ),
      exam: PhysicalExam.fromMap(
        Map<String, dynamic>.from(
          (d['exam'] as Map<dynamic, dynamic>?) ?? const <dynamic, dynamic>{},
        ),
      ),
      diagnoses: ((d['diagnoses'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                Diagnosis.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      assessment: (d['assessment'] as String?) ?? '',
      plan: (d['plan'] as String?) ?? '',
      procedures: ((d['procedures'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                ProcedureRecord.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      signedAt: (d['signedAt'] as Timestamp?)?.toDate(),
      signatureHash: d['signatureHash'] as String?,
      amendsEncounterId: d['amendsEncounterId'] as String?,
      amendmentReason: d['amendmentReason'] as String?,
      appointmentId: d['appointmentId'] as String?,
      attachmentIds: ((d['attachmentIds'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  static ClinicalDocument _documentFrom(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? const <String, dynamic>{};

    return ClinicalDocument(
      id: doc.id,
      encounterId: (d['encounterId'] as String?) ?? '',
      patientId: (d['patientId'] as String?) ?? '',
      professionalId: (d['professionalId'] as String?) ?? '',
      type: ClinicalDocumentType.fromName(d['type'] as String?),
      issuedAt: (d['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      content: (d['content'] as String?) ?? '',
      professionalName: d['professionalName'] as String?,
      professionalCrm: d['professionalCrm'] as String?,
      patientName: d['patientName'] as String?,
      items: ((d['items'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> m) =>
                PrescriptionItem.fromMap(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false),
      validUntil: (d['validUntil'] as Timestamp?)?.toDate(),
      pdfUrl: d['pdfUrl'] as String?,
      contentHash: d['contentHash'] as String?,
      signatureProvider: d['signatureProvider'] as String?,
      signedAt: (d['signedAt'] as Timestamp?)?.toDate(),
      verificationCode: d['verificationCode'] as String?,
      cancelled: (d['cancelled'] as bool?) ?? false,
      cancellationReason: d['cancellationReason'] as String?,
    );
  }

  /// Hash local, para conferir que o documento exibido não foi alterado.
  ///
  /// O hash que vale é o gravado pelo servidor na assinatura. Este permite ao
  /// aplicativo detectar divergência sem precisar confiar na infraestrutura.
  static String contentHash(Map<String, dynamic> content) =>
      sha256.convert(utf8.encode(jsonEncode(content))).toString();

  // ------------------------------------------------------- Resumo pós-consulta

  /// Cria ou atualiza o rascunho — nunca visível à família enquanto
  /// `status` continuar `draft`. A regra do servidor garante isso, não só
  /// esta chamada.
  Future<Result<void>> saveVisitSummaryDraft({
    required String encounterId,
    required String patientId,
    required String professionalId,
    String guidance = '',
    String careInstructions = '',
    List<String> warningSigns = const <String>[],
    String followUpNotes = '',
    DateTime? followUpDate,
    List<String> releasedDocumentIds = const <String>[],
  }) =>
      guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> existing =
            await _visitSummaries.doc(encounterId).get();

        final VisitSummary? current =
            existing.exists ? VisitSummaryMapper.fromFirestore(existing) : null;

        // Uma vez finalizado, edição direta para — correção passa a ser
        // retificação (`amendVisitSummary`). Checado aqui, não só na
        // regra: falha com mensagem clara em vez de um permission-denied
        // genérico que ninguém entenderia de onde veio.
        if (current != null && current.status != VisitSummaryStatus.draft) {
          throw const ValidationFailure(
            'Este resumo já foi finalizado — para corrigir, use a '
            'retificação em vez de editar direto.',
          );
        }

        final VisitSummary summary = VisitSummary(
          encounterId: encounterId,
          patientId: patientId,
          professionalId: professionalId,
          createdAt: current?.createdAt ?? DateTime.now(),
          guidance: guidance,
          careInstructions: careInstructions,
          warningSigns: warningSigns,
          followUpNotes: followUpNotes,
          followUpDate: followUpDate,
          releasedDocumentIds: releasedDocumentIds,
        );

        await _visitSummaries
            .doc(encounterId)
            .set(VisitSummaryMapper.toFirestore(summary));
      });

  /// Trava o conteúdo — o profissional confirmou que está pronto, mas a
  /// família ainda não vê. Passo próprio, separado de liberar: "revisar
  /// antes de confirmar" precisa ser uma ação que existe de verdade, não
  /// um checkbox dentro de outra ação.
  Future<Result<void>> finalizeVisitSummary(String encounterId) =>
      guard(() async {
        await _visitSummaries.doc(encounterId).update(<String, dynamic>{
          'status': VisitSummaryStatus.finalized.name,
          'finalizedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Libera o resumo já finalizado para a família — exige que o status já
  /// seja `finalized`, não pula direto de `draft`. Checagem dupla: aqui no
  /// repositório (falha cedo, com mensagem clara) e na regra do servidor
  /// (a que realmente impede, mesmo se este código tiver bug).
  Future<Result<void>> releaseVisitSummary(String encounterId) => guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _visitSummaries.doc(encounterId).get();
        final VisitSummary? current =
            doc.exists ? VisitSummaryMapper.fromFirestore(doc) : null;

        if (current?.status != VisitSummaryStatus.finalized) {
          throw const ValidationFailure(
            'Finalize o resumo antes de liberar — confirme que está pronto.',
          );
        }

        await _visitSummaries.doc(encounterId).update(<String, dynamic>{
          'status': VisitSummaryStatus.released.name,
          'releasedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Corrige um resumo já liberado — nunca sobrescreve o que a família já
  /// viu. Cria um documento novo (novo `encounterId` sintético,
  /// `original_amend_{timestamp}`), copiando o conteúdo do original como
  /// ponto de partida, marcado como retificação. O original permanece
  /// intacto para sempre — mesmo padrão de `amendEncounter`.
  Future<Result<String>> amendVisitSummary({
    required String originalEncounterId,
    required String reason,
  }) =>
      guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> original =
            await _visitSummaries.doc(originalEncounterId).get();

        if (!original.exists) {
          throw const ValidationFailure('Resumo original não encontrado.');
        }

        final VisitSummary source = VisitSummaryMapper.fromFirestore(original);
        if (source.status != VisitSummaryStatus.released) {
          throw const ValidationFailure(
            'Só um resumo já liberado precisa de retificação — rascunho e '
            'finalizado ainda são editáveis diretamente.',
          );
        }

        final String newId =
            '${originalEncounterId}_amend_${DateTime.now().millisecondsSinceEpoch}';

        final VisitSummary amendment = VisitSummary(
          encounterId: newId,
          patientId: source.patientId,
          professionalId: source.professionalId,
          createdAt: DateTime.now(),
          status: VisitSummaryStatus.draft,
          guidance: source.guidance,
          careInstructions: source.careInstructions,
          warningSigns: source.warningSigns,
          followUpNotes: source.followUpNotes,
          followUpDate: source.followUpDate,
          releasedDocumentIds: source.releasedDocumentIds,
          amendsSummaryId: originalEncounterId,
          amendmentReason: reason,
        );

        await _visitSummaries
            .doc(newId)
            .set(VisitSummaryMapper.toFirestore(amendment));

        return newId;
      });

  /// Lido pelo profissional (rascunho ou liberado) e pela família (só
  /// depois de liberado — a regra do servidor filtra isso, este método só
  /// espelha o documento como ele estiver).
  Stream<VisitSummary?> watchVisitSummary(String encounterId) =>
      _visitSummaries.doc(encounterId).snapshots().map(
            (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
                ? VisitSummaryMapper.fromFirestore(doc)
                : null,
          );

  /// Todos os resumos liberados de uma criança — usado pela família, que
  /// não conhece o id de cada atendimento de antemão.
  ///
  /// Os dois `where()` são obrigatórios, não só um filtro de conveniência:
  /// a regra do servidor (`ownsChild(patientId) && status == 'released'`)
  /// só consegue validar uma CONSULTA (lista, não leitura de documento
  /// único) se os filtros da própria consulta já garantirem as duas
  /// condições — o Firestore não confia no conteúdo real dos documentos
  /// para decidir se a consulta é permitida, só na estrutura da consulta
  /// em si. Filtrar `status` no cliente depois de buscar tudo faria a
  /// consulta inteira ser negada, não só devolver menos resultado.
  Stream<List<VisitSummary>> watchReleasedVisitSummaries(String childId) =>
      _visitSummaries
          .where('patientId', isEqualTo: childId)
          .where('status', isEqualTo: VisitSummaryStatus.released.name)
          .orderBy('releasedAt', descending: true)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map(VisitSummaryMapper.fromFirestore)
                .toList(growable: false),
          );
}
