import 'package:equatable/equatable.dart';

/// Questionário de pré-consulta, preenchido pelo responsável antes do
/// atendimento — nunca pelo profissional, nunca gerado automaticamente.
///
/// ## Por que os nomes de campo são deliberadamente diferentes de [Anamnesis]
///
/// `Anamnesis` (em `clinical_record.dart`) é o registro clínico, escrito
/// pelo profissional, com força de documento médico. Isto aqui é
/// informação bruta que a família forneceu antes da consulta — mesmo
/// assunto em alguns campos (sintomas, alergia, medicamento em uso), mas
/// nomeado diferente de propósito, para que confundir os dois na tela ou
/// no código seja visivelmente um erro, não um deslize fácil de não notar.
///
/// A UI que mostra isto ao profissional é obrigada a rotular
/// "Informações fornecidas pelo responsável" — não é um requisito de
/// código, mas o motivo de ID/nome de campo serem tão explicitamente
/// separados de `Anamnesis` é justamente não deixar a linha entre os dois
/// ficar borrada em nenhum lugar do sistema.
class PreVisitQuestionnaire extends Equatable {
  const PreVisitQuestionnaire({
    required this.appointmentId,
    required this.patientId,
    required this.childId,
    required this.professionalId,
    required this.submittedAt,
    this.reason = '',
    this.symptoms = const <String>[],
    this.symptomsStartedAt,
    this.hasFever = false,
    this.feverTemperatureC,
    this.feedingNotes = '',
    this.sleepNotes = '',
    this.eliminationNotes,
    this.currentMedications = const <String>[],
    this.allergies = const <String>[],
    this.additionalNotes = '',
    this.attachmentUrls = const <String>[],
  });

  final String appointmentId;

  /// Uid do responsável que preencheu — não confundir com [childId].
  final String patientId;

  final String childId;

  /// Denormalizado do agendamento, para a regra de leitura do profissional
  /// não depender de consultar o agendamento separadamente.
  final String professionalId;

  final DateTime submittedAt;

  final String reason;
  final List<String> symptoms;
  final DateTime? symptomsStartedAt;
  final bool hasFever;
  final double? feverTemperatureC;
  final String feedingNotes;
  final String sleepNotes;

  /// Nulo quando não pertinente (ex.: recém-nascido) — não é campo
  /// obrigatório em todo formulário.
  final String? eliminationNotes;

  final List<String> currentMedications;
  final List<String> allergies;
  final String additionalNotes;
  final List<String> attachmentUrls;

  /// Verdadeiro se a família preencheu qualquer coisa além do mínimo — usado
  /// para não mostrar o bloco inteiro ao profissional quando só existe um
  /// registro vazio (ex.: rascunho nunca terminado).
  bool get hasContent =>
      reason.isNotEmpty ||
      symptoms.isNotEmpty ||
      hasFever ||
      feedingNotes.isNotEmpty ||
      sleepNotes.isNotEmpty ||
      (eliminationNotes?.isNotEmpty ?? false) ||
      currentMedications.isNotEmpty ||
      allergies.isNotEmpty ||
      additionalNotes.isNotEmpty ||
      attachmentUrls.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
        appointmentId,
        patientId,
        childId,
        professionalId,
        submittedAt,
        reason,
        symptoms,
        symptomsStartedAt,
        hasFever,
        feverTemperatureC,
        feedingNotes,
        sleepNotes,
        eliminationNotes,
        currentMedications,
        allergies,
        additionalNotes,
        attachmentUrls,
      ];
}
