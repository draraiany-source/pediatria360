import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:equatable/equatable.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/models/pre_visit_questionnaire_model.dart';
import '../../../shared/domain/entities/pre_visit_questionnaire.dart';

/// Situação de uma consulta.
/// Modalidade do atendimento.
///
/// Ausente em agendamentos criados antes desta mudança — por isso o parser
/// (`fromName`) cai em `teleconsulta` por padrão: era a única modalidade
/// que existia até agora, então um registro antigo sem o campo é
/// corretamente interpretado como teleconsulta, não como um valor
/// arbitrário.
enum AppointmentType {
  presencial,
  teleconsulta;

  static AppointmentType fromName(String? value) =>
      AppointmentType.values.firstWhere(
        (AppointmentType t) => t.name == value,
        orElse: () => AppointmentType.teleconsulta,
      );

  String get label => switch (this) {
        AppointmentType.presencial => 'Presencial',
        AppointmentType.teleconsulta => 'Teleconsulta',
      };
}

enum AppointmentStatus {
  requested,
  confirmed,
  inProgress,
  completed,
  cancelled,
  noShow;

  static AppointmentStatus fromName(String? value) =>
      AppointmentStatus.values.firstWhere(
        (AppointmentStatus s) => s.name == value,
        orElse: () => AppointmentStatus.requested,
      );

  String get label => switch (this) {
        AppointmentStatus.requested => 'Aguardando confirmação',
        AppointmentStatus.confirmed => 'Confirmada',
        AppointmentStatus.inProgress => 'Em andamento',
        AppointmentStatus.completed => 'Realizada',
        AppointmentStatus.cancelled => 'Cancelada',
        AppointmentStatus.noShow => 'Não compareceu',
      };

  bool get isActive =>
      this == AppointmentStatus.requested ||
      this == AppointmentStatus.confirmed ||
      this == AppointmentStatus.inProgress;
}

/// Uma consulta agendada.
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.professionalId,
    required this.professionalName,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
    this.type = AppointmentType.teleconsulta,
    this.childId,
    this.childName,
    this.reason,
    this.priceCents = 0,
    this.paid = false,
    this.roomUrl,
    this.notes,
    this.specialty,
    this.workflowStatus,
    this.arrivedAt,
    this.checkInNotes,
    this.roomLabel,
  });

  factory Appointment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return Appointment(
      id: doc.id,
      patientId: (data['patientId'] as String?) ?? '',
      professionalId: (data['professionalId'] as String?) ?? '',
      professionalName: (data['professionalName'] as String?) ?? '',
      startsAt: (data['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      status: AppointmentStatus.fromName(data['status'] as String?),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: AppointmentType.fromName(data['type'] as String?),
      childId: data['childId'] as String?,
      childName: data['childName'] as String?,
      reason: data['reason'] as String?,
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      paid: (data['paid'] as bool?) ?? false,
      roomUrl: data['roomUrl'] as String?,
      notes: data['notes'] as String?,
      specialty: data['specialty'] as String?,
      workflowStatus: data['workflowStatus'] as String?,
      arrivedAt: (data['arrivedAt'] as Timestamp?)?.toDate(),
      checkInNotes: data['checkInNotes'] as String?,
      roomLabel: data['roomLabel'] as String?,
    );
  }

  final String id;
  final String patientId;
  final String professionalId;
  final String professionalName;
  final DateTime startsAt;
  final int durationMinutes;
  final AppointmentStatus status;
  final DateTime createdAt;
  final AppointmentType type;

  final String? childId;
  final String? childName;
  final String? reason;
  final int priceCents;
  final bool paid;

  /// URL da sala de vídeo. Só é preenchida pelo servidor perto do horário —
  /// um link permanente circulando por e-mail é risco de invasão de consulta.
  final String? roomUrl;

  final String? notes;
  final String? specialty;

  /// Fluxo operacional da recepção (mais granular que [status]).
  final String? workflowStatus;
  final DateTime? arrivedAt;
  final String? checkInNotes;
  final String? roomLabel;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  bool get isPast => endsAt.isBefore(DateTime.now());

  /// A sala abre 10 minutos antes e fecha 15 depois do fim previsto.
  bool get canEnterRoom {
    if (status != AppointmentStatus.confirmed &&
        status != AppointmentStatus.inProgress) {
      return false;
    }
    final DateTime now = DateTime.now();
    return now.isAfter(startsAt.subtract(const Duration(minutes: 10))) &&
        now.isBefore(endsAt.add(const Duration(minutes: 15)));
  }

  /// Cancelamento sem custo até 24 h antes — depois disso o horário já não
  /// pode ser reocupado.
  bool get canCancelFree =>
      startsAt.difference(DateTime.now()).inHours >= 24;

  @override
  List<Object?> get props => <Object?>[id, status, startsAt, roomUrl, type, workflowStatus, arrivedAt];
}

/// Um horário disponível na agenda.
class TimeSlot extends Equatable {
  const TimeSlot({
    required this.startsAt,
    required this.durationMinutes,
    required this.available,
  });

  factory TimeSlot.fromMap(Map<String, dynamic> map) => TimeSlot(
        startsAt: DateTime.parse(map['startsAt'] as String).toLocal(),
        durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
        available: (map['available'] as bool?) ?? true,
      );

  final DateTime startsAt;
  final int durationMinutes;
  final bool available;

  @override
  List<Object?> get props => <Object?>[startsAt, available];
}

/// Perfil público de um profissional atendente.
class ProfessionalProfile extends Equatable {
  const ProfessionalProfile({
    required this.uid,
    required this.name,
    required this.specialty,
    required this.priceCents,
    this.photoUrl,
    this.crm,
    this.bio,
    this.rating = 0,
    this.consultationCount = 0,
    this.acceptsNewPatients = true,
  });

  factory ProfessionalProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return ProfessionalProfile(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      specialty: (data['specialty'] as String?) ?? 'Pediatria geral',
      priceCents: (data['consultationPriceCents'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      crm: data['crm'] as String?,
      bio: data['bio'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      consultationCount: (data['consultationCount'] as num?)?.toInt() ?? 0,
      acceptsNewPatients: (data['acceptsNewPatients'] as bool?) ?? true,
    );
  }

  final String uid;
  final String name;
  final String specialty;
  final int priceCents;
  final String? photoUrl;
  final String? crm;
  final String? bio;
  final double rating;
  final int consultationCount;
  final bool acceptsNewPatients;

  @override
  List<Object?> get props => <Object?>[uid, name, priceCents];
}

/// Acesso à telemedicina.
///
/// ## Sobre a sala de vídeo
///
/// O app não implementa WebRTC próprio. A Cloud Function `joinConsultation`
/// devolve uma URL de sala de um provedor externo (Daily, Whereby, Twilio),
/// válida por tempo limitado e só para os dois participantes. Construir
/// videoconferência médica do zero — com gravação, consentimento, retenção e
/// conformidade — é um produto inteiro, não uma tela.
class TelemedicineRepository {
  const TelemedicineRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(FirestorePaths.appointments);

  CollectionReference<Map<String, dynamic>> get _preVisitQuestionnaires =>
      _firestore.collection(FirestorePaths.preVisitQuestionnaires);

  /// O responsável preenche/atualiza o questionário antes da consulta.
  ///
  /// Documento com o mesmo id do agendamento — um questionário por
  /// consulta, `set()` sobrescreve se a família editar antes do
  /// atendimento começar. Depois que o atendimento inicia, a regra do
  /// servidor bloqueia escrita (ver firestore.rules) — não é este método
  /// que impede, é a regra, então o bloqueio vale mesmo se o app tiver bug.
  Future<Result<void>> submitPreVisitQuestionnaire({
    required String appointmentId,
    required String patientId,
    required String childId,
    required String professionalId,
    String reason = '',
    List<String> symptoms = const <String>[],
    DateTime? symptomsStartedAt,
    bool hasFever = false,
    double? feverTemperatureC,
    String feedingNotes = '',
    String sleepNotes = '',
    String? eliminationNotes,
    List<String> currentMedications = const <String>[],
    List<String> allergies = const <String>[],
    String additionalNotes = '',
    List<String> attachmentUrls = const <String>[],
  }) =>
      guard(() async {
        final PreVisitQuestionnaire q = PreVisitQuestionnaire(
          appointmentId: appointmentId,
          patientId: patientId,
          childId: childId,
          professionalId: professionalId,
          submittedAt: DateTime.now(),
          reason: reason,
          symptoms: symptoms,
          symptomsStartedAt: symptomsStartedAt,
          hasFever: hasFever,
          feverTemperatureC: feverTemperatureC,
          feedingNotes: feedingNotes,
          sleepNotes: sleepNotes,
          eliminationNotes: eliminationNotes,
          currentMedications: currentMedications,
          allergies: allergies,
          additionalNotes: additionalNotes,
          attachmentUrls: attachmentUrls,
        );
        await _preVisitQuestionnaires
            .doc(appointmentId)
            .set(PreVisitQuestionnaireMapper.toFirestore(q));
      });

  /// Lida pelo profissional antes/durante o atendimento, e pelo responsável
  /// que preencheu, para conferir o que enviou. `null` quando a família
  /// ainda não preencheu nada — estado normal, não erro.
  Stream<PreVisitQuestionnaire?> watchPreVisitQuestionnaire(
    String appointmentId,
  ) =>
      _preVisitQuestionnaires.doc(appointmentId).snapshots().map(
            (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
                ? PreVisitQuestionnaireMapper.fromFirestore(doc)
                : null,
          );

  /// Lê a disponibilidade semanal do próprio profissional.
  ///
  /// Mesmo formato que `getAvailability` já lê no servidor:
  /// `{"1": ["09:00", "09:30", ...]}`, chave sendo o dia da semana em ISO
  /// (0 = domingo, igual ao `getUTCDay()` do JavaScript). Não existe uma
  /// coleção `professional_schedules` separada — o campo já vive direto no
  /// documento do próprio usuário, e é lá que a Function sempre leu.
  Future<Result<Map<String, List<String>>>> myWeeklyAvailability(
    String uid,
  ) =>
      guard(() async {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await _firestore.collection(FirestorePaths.users).doc(uid).get();

        final Map<String, dynamic> raw =
            (doc.data()?['availability'] as Map<String, dynamic>?) ??
                const <String, dynamic>{};

        return raw.map(
          (String weekday, dynamic times) => MapEntry(
            weekday,
            (times as List<dynamic>).cast<String>(),
          ),
        );
      });

  /// Grava a disponibilidade semanal — escreve direto no próprio documento,
  /// sem Function: `availability` não está em `serverOnlyFields()` nas
  /// regras, e o dono sempre pôde escrever no próprio documento.
  ///
  /// `weekday` é string ("0".."6") para bater exatamente com a chave que
  /// `getAvailability` espera no Firestore — um `Map<int, ...>` seria
  /// convertido para string na gravação de qualquer forma, então já grava
  /// no formato final em vez de converter duas vezes.
  Future<Result<void>> setWeeklyAvailability({
    required String uid,
    required Map<String, List<String>> availability,
    required int consultationMinutes,
  }) =>
      guard(() async {
        await _firestore.collection(FirestorePaths.users).doc(uid).update(
          <String, dynamic>{
            'availability': availability,
            'consultationMinutes': consultationMinutes,
          },
        );
      });

  /// Profissionais disponíveis para atendimento.
  Future<Result<List<ProfessionalProfile>>> professionals() =>
      guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection(FirestorePaths.users)
            .where('role', isEqualTo: 'professional')
            .where('professionalVerified', isEqualTo: true)
            .where('acceptsNewPatients', isEqualTo: true)
            .limit(50)
            .get();

        return snapshot.docs
            .map(ProfessionalProfile.fromFirestore)
            .toList(growable: false);
      });

  /// Horários livres de um profissional numa data.
  ///
  /// Calculado no servidor: a agenda cruza disponibilidade declarada com
  /// consultas já marcadas, e nenhuma das duas coisas o cliente deve ver por
  /// inteiro — a agenda de um médico é informação dele.
  Future<Result<List<TimeSlot>>> availability({
    required String professionalId,
    required DateTime date,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response =
            await _functions.httpsCallable('getAvailability').call(
          <String, dynamic>{
            'professionalId': professionalId,
            'date': DateTime(date.year, date.month, date.day)
                .toUtc()
                .toIso8601String(),
          },
        );

        final List<dynamic> slots =
            (response.data as Map<dynamic, dynamic>)['slots'] as List<dynamic>;

        return slots
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> m) =>
                TimeSlot.fromMap(Map<String, dynamic>.from(m)))
            .toList(growable: false);
      });

  /// Solicita uma consulta.
  ///
  /// A reserva do horário acontece em transação no servidor — dois pais
  /// tocando "agendar" no mesmo segundo não podem ficar com o mesmo horário.
  Future<Result<String>> book({
    required String professionalId,
    required DateTime startsAt,
    String? childId,
    String? reason,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> response =
            await _functions.httpsCallable('bookAppointment').call(
          <String, dynamic>{
            'professionalId': professionalId,
            'startsAt': startsAt.toUtc().toIso8601String(),
            if (childId != null) 'childId': childId,
            if (reason != null) 'reason': reason,
          },
        );

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);
        return (data['appointmentId'] as String?) ?? '';
      });

  Stream<List<Appointment>> watchMyAppointments(String uid) => _appointments
      .where('patientId', isEqualTo: uid)
      .orderBy('startsAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) =>
            s.docs.map(Appointment.fromFirestore).toList(growable: false),
      );

  /// Agenda do profissional.
  Stream<List<Appointment>> watchProfessionalAgenda(String uid) =>
      _appointments
          .where('professionalId', isEqualTo: uid)
          .orderBy('startsAt')
          .limit(100)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(Appointment.fromFirestore).toList(growable: false),
          );

  /// Agendamentos de uma crianca (visao 360 / timeline clinica).
  Stream<List<Appointment>> watchChildAppointments(String childId) =>
      _appointments
          .where('childId', isEqualTo: childId)
          .orderBy('startsAt', descending: true)
          .limit(40)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map(Appointment.fromFirestore).toList(growable: false),
          );

  Future<Result<void>> cancel(String appointmentId) => guard(() async {
        await _appointments.doc(appointmentId).update(<String, dynamic>{
          'status': AppointmentStatus.cancelled.name,
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });

  /// Confirma uma consulta solicitada. Só o profissional dono do
  /// agendamento pode — a mesma regra que já protege `cancel()` (que é do
  /// paciente) protege esta (que é do profissional), por
  /// `resource.data.professionalId == request.auth.uid`.
  Future<Result<void>> confirm(String appointmentId) => guard(() async {
        await _appointments.doc(appointmentId).update(<String, dynamic>{
          'status': AppointmentStatus.confirmed.name,
        });
      });

  Future<Result<void>> markCompleted(String appointmentId) => guard(() async {
        await _appointments.doc(appointmentId).update(<String, dynamic>{
          'status': AppointmentStatus.completed.name,
        });
      });

  /// Entra na sala. A URL é gerada na hora e expira.
  Future<Result<String>> joinRoom(String appointmentId) => guard(() async {
        final HttpsCallableResult<dynamic> response = await _functions
            .httpsCallable('joinConsultation')
            .call(<String, dynamic>{'appointmentId': appointmentId});

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

        final String? url = data['roomUrl'] as String?;
        if (url == null || url.isEmpty) {
          throw StateError('Sala indisponível no momento.');
        }
        return url;
      });
}
