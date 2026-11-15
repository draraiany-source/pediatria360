import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/utils/result.dart';

/// Acesso da gestão integrada às Functions (agenda, CRM, anamnese,
/// automações, WhatsApp, marketing, Central de IA e uso).
///
/// Tudo que grava passa por Function com papel e parâmetros conferidos no
/// servidor; o app só lê direto o que as regras liberam para o papel.
class ManagementRepository {
  const ManagementRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<Result<Map<String, dynamic>>> _call(
    String name,
    Map<String, dynamic> data,
  ) =>
      guard(() async {
        final HttpsCallableResult<dynamic> r =
            await _functions.httpsCallable(name).call(data);
        final Object? raw = r.data;
        return raw is Map
            ? _deepMap(raw)
            : <String, dynamic>{'value': raw};
      });

  static Map<String, dynamic> _deepMap(Map<dynamic, dynamic> m) =>
      m.map((dynamic k, dynamic v) => MapEntry(k.toString(), _deep(v)));

  static Object? _deep(Object? v) {
    if (v is Map) return _deepMap(v);
    if (v is List) return v.map(_deep).toList(growable: false);
    return v;
  }

  // ------------------------------------------------------------ Central de IA

  Future<Result<Map<String, dynamic>>> insights(String clinicId) =>
      _call('getManagementInsights', <String, dynamic>{'clinicId': clinicId});

  /// [requestId] identifica a pergunta: repetir o envio (rede instável) não
  /// conta duas vezes no limite de uso.
  Future<Result<Map<String, dynamic>>> ask(
    String clinicId,
    String question, {
    required String requestId,
  }) =>
      _call('askManagementAssistant', <String, dynamic>{
        'clinicId': clinicId,
        'question': question,
        'requestId': requestId,
      });

  // ------------------------------------------------------------ CRM

  Future<Result<Map<String, dynamic>>> crmIndicators(String clinicId) =>
      _call('getCrmIndicators', <String, dynamic>{'clinicId': clinicId});

  Future<Result<Map<String, dynamic>>> crmDuplicates(String clinicId) =>
      _call('findCrmDuplicates', <String, dynamic>{'clinicId': clinicId});

  Stream<List<Map<String, dynamic>>> watchCrmContacts(String clinicId) =>
      _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('crm_contacts')
          .limit(200)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .where((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    d.data()['mergedInto'] == null)
                .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    <String, dynamic>{'key': d.id, ...d.data()})
                .toList(growable: false),
          );

  // ------------------------------------------------------------ WhatsApp e automações

  Future<Result<Map<String, dynamic>>> whatsAppStatus(String clinicId) =>
      _call('getWhatsAppStatus', <String, dynamic>{'clinicId': clinicId});

  Future<Result<Map<String, dynamic>>> setAutomationsPaused(
    String clinicId, {
    required bool paused,
  }) =>
      _call('setClinicAutomationsPaused', <String, dynamic>{
        'clinicId': clinicId,
        'paused': paused,
      });

  Future<Result<Map<String, dynamic>>> saveAutomationRule(
    String clinicId,
    String kind,
    Map<String, dynamic> rule,
  ) =>
      _call('saveAutomationRule', <String, dynamic>{
        ...rule,
        'clinicId': clinicId,
        'kind': kind,
      });

  Future<Result<Map<String, dynamic>>> processQueueNow(String clinicId) =>
      _call('processMessageQueueNow', <String, dynamic>{'clinicId': clinicId});

  Future<Result<Map<String, dynamic>>> cancelQueuedMessage(
    String clinicId,
    String messageId,
  ) =>
      _call('cancelQueuedMessage', <String, dynamic>{
        'clinicId': clinicId,
        'messageId': messageId,
      });

  Stream<List<Map<String, dynamic>>> watchAutomations(String clinicId) =>
      _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('automations')
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    <String, dynamic>{'kind': d.id, ...d.data()})
                .toList(growable: false),
          );

  Stream<List<Map<String, dynamic>>> watchInbox(String clinicId) => _firestore
      .collection('clinics')
      .doc(clinicId)
      .collection('whatsapp_inbox')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                <String, dynamic>{'id': d.id, ...d.data()})
            .toList(growable: false),
      );

  Future<Result<Map<String, dynamic>>> updateInboxItem(
    String clinicId,
    String itemId,
    String status,
  ) =>
      _call('updateInboxItem', <String, dynamic>{
        'clinicId': clinicId,
        'itemId': itemId,
        'status': status,
      });

  // ------------------------------------------------------------ Marketing

  Stream<List<Map<String, dynamic>>> watchCampaigns(String clinicId) =>
      _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('campaigns')
          .limit(50)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) => s.docs
                .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    <String, dynamic>{'id': d.id, ...d.data()})
                .toList(growable: false),
          );

  Future<Result<Map<String, dynamic>>> saveCampaignDraft(
    String clinicId, {
    required String title,
    required String body,
    int frequencyCapDays = 7,
    Map<String, dynamic> segment = const <String, dynamic>{},
    String? campaignId,
  }) =>
      _call('saveCampaignDraft', <String, dynamic>{
        'clinicId': clinicId,
        'title': title,
        'body': body,
        'frequencyCapDays': frequencyCapDays,
        'segment': segment,
        if (campaignId != null) 'campaignId': campaignId,
      });

  Future<Result<Map<String, dynamic>>> previewCampaign(
    String clinicId,
    String campaignId,
  ) =>
      _call('previewCampaign', <String, dynamic>{
        'clinicId': clinicId,
        'campaignId': campaignId,
      });

  Future<Result<Map<String, dynamic>>> approveCampaign(
    String clinicId,
    String campaignId,
  ) =>
      _call('approveCampaign', <String, dynamic>{
        'clinicId': clinicId,
        'campaignId': campaignId,
      });

  Future<Result<Map<String, dynamic>>> cancelCampaign(
    String clinicId,
    String campaignId,
  ) =>
      _call('cancelCampaign', <String, dynamic>{
        'clinicId': clinicId,
        'campaignId': campaignId,
      });

  // ------------------------------------------------------------ Uso e custos

  Future<Result<Map<String, dynamic>>> usageDashboard(String clinicId) =>
      _call('getUsageDashboard', <String, dynamic>{'clinicId': clinicId});

  // ------------------------------------------------------------ Anamnese

  Future<Result<Map<String, dynamic>>> startAnamnesis(String appointmentId) =>
      _call('startAnamnesis', <String, dynamic>{'appointmentId': appointmentId});

  Future<Result<Map<String, dynamic>>> saveAnamnesisDraft(
    String responseId,
    Map<String, dynamic> answers, {
    List<String> confirmedReuse = const <String>[],
  }) =>
      _call('saveAnamnesisDraft', <String, dynamic>{
        'responseId': responseId,
        'answers': answers,
        'confirmedReuse': confirmedReuse,
      });

  Future<Result<Map<String, dynamic>>> submitAnamnesis(String responseId) =>
      _call('submitAnamnesis', <String, dynamic>{'responseId': responseId});

  Future<Result<Map<String, dynamic>>> amendAnamnesis(String responseId) =>
      _call('amendAnamnesis', <String, dynamic>{'responseId': responseId});

  Future<Result<Map<String, dynamic>>> anamnesisForVisit(
    String appointmentId,
  ) =>
      _call('getAnamnesisForVisit',
          <String, dynamic>{'appointmentId': appointmentId});

  Future<Result<Map<String, dynamic>>> reviewAnamnesis(
    String responseId,
    String notes,
  ) =>
      _call('reviewAnamnesis', <String, dynamic>{
        'responseId': responseId,
        'notes': notes,
      });
}
