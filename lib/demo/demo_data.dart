import '../core/config/app_assets.dart';

/// Dados 100% ficticios da demonstracao web.
///
/// Nenhum registro aqui vem de paciente, clinica ou mockup: os nomes levam o
/// sobrenome "Exemplo" para que ninguem os confunda com pessoas reais, e as
/// datas sao relativas ao dia de hoje para a agenda nunca ficar vazia.
class DemoPatient {
  DemoPatient({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.sexLabel,
    required this.guardianName,
    this.allergies = const <String>[],
    this.avatarAsset,
    this.weightKg,
    this.weighedAt,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String sexLabel;
  final String guardianName;
  final List<String> allergies;

  /// Última pesagem registrada. A consulta pode atualizar.
  double? weightKg;
  DateTime? weighedAt;

  /// Idade gestacional ao nascer, em dias. `null` = não informada.
  int? gestationalAgeDays;

  /// Avatar escolhido pelo responsavel (exemplo). `null` = sem avatar.
  String? avatarAsset;

  String get ageLabel {
    final DateTime now = DateTime.now();
    int months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) months--;
    if (months < 24) return '$months ${months == 1 ? 'mês' : 'meses'}';
    final int years = months ~/ 12;
    return '$years anos';
  }
}

class DemoEncounter {
  const DemoEncounter({
    required this.patientId,
    required this.date,
    required this.type,
    required this.summary,
    this.professionalId = 'prof-a',
  });

  final String patientId;
  final DateTime date;
  final String type;
  final String summary;
  final String professionalId;
}

enum DemoAppointmentKind { presencial, teleconsulta }

enum DemoAppointmentStatus {
  agendado,
  confirmado,
  chegou,
  concluido,

  /// A família pediu outro horário (lembrete ou assistente).
  reagendar,
  cancelado;

  /// Ainda ocupa o horário na agenda.
  bool get holdsSlot => this != DemoAppointmentStatus.cancelado;

  /// Status que a recepção escolhe à mão no detalhe.
  static const List<DemoAppointmentStatus> manual = <DemoAppointmentStatus>[
    agendado,
    confirmado,
    chegou,
    concluido,
  ];
}

class DemoAppointment {
  DemoAppointment({
    required this.id,
    required this.patientId,
    required this.start,
    required this.kind,
    required this.status,
    required this.reason,
    this.professionalId = 'prof-a',
    this.durationMinutes = 30,
    this.typeLabel,
  });

  final String id;
  final String patientId;

  /// Muda no reagendamento; o id (e a pré-consulta) continua o mesmo.
  DateTime start;
  final DemoAppointmentKind kind;
  DemoAppointmentStatus status;
  final String reason;
  final String professionalId;
  final int durationMinutes;
  final String? typeLabel;

  DateTime get end => start.add(Duration(minutes: durationMinutes));
}

enum DemoVaccineStatus { registrada, pendente }

class DemoVaccineRecord {
  const DemoVaccineRecord({
    required this.patientId,
    required this.name,
    required this.dose,
    required this.status,
    this.date,
  });

  final String patientId;
  final String name;
  final String dose;
  final DemoVaccineStatus status;
  final DateTime? date;
}

class DemoArticle {
  const DemoArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.minutes,
    required this.summary,
  });

  final String id;
  final String title;
  final String category;
  final int minutes;
  final String summary;
}

enum DemoInvoiceStatus { aberto, pago, atrasado }

class DemoInvoice {
  const DemoInvoice({
    required this.id,
    required this.description,
    required this.patientId,
    required this.amount,
    required this.due,
    required this.status,
  });

  final String id;
  final String description;
  final String patientId;
  final double amount;
  final DateTime due;
  final DemoInvoiceStatus status;
}

/// Gera o conjunto ficticio. Chamado uma vez por sessao; recarregar a pagina
/// restaura o estado inicial (nada e salvo).
class DemoSeed {
  const DemoSeed._();

  static DateTime _today() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _daysAgo(int days) => _today().subtract(Duration(days: days));

  static DateTime _monthsAgo(int months, {int day = 12}) {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month - months, day);
  }

  static List<DemoPatient> patients() => <DemoPatient>[
    DemoPatient(
      id: 'p1',
      name: 'Luna Exemplo Souza',
      birthDate: _monthsAgo(14, day: 3),
      sexLabel: 'Menina',
      guardianName: 'Responsável Exemplo A',
      allergies: const <String>['Exemplo: proteína do leite'],
      avatarAsset: AppAssets.avatarMeninaCoral,
      weightKg: 10.2,
      weighedAt: _daysAgo(10),
    ),
    DemoPatient(
      id: 'p2',
      name: 'Theo Exemplo Lima',
      birthDate: _monthsAgo(50, day: 21),
      sexLabel: 'Menino',
      guardianName: 'Responsável Exemplo B',
      weightKg: 16.5,
      weighedAt: _daysAgo(150),
    ),
    DemoPatient(
      id: 'p3',
      name: 'Maya Exemplo Rocha',
      birthDate: _monthsAgo(7, day: 9),
      sexLabel: 'Menina',
      guardianName: 'Responsável Exemplo C',
      avatarAsset: AppAssets.avatarBebeTurquesa,
    ),
    DemoPatient(
      id: 'p4',
      name: 'Davi Exemplo Nunes',
      birthDate: _monthsAgo(98, day: 15),
      sexLabel: 'Menino',
      guardianName: 'Responsável Exemplo D',
      allergies: const <String>['Medicamento Exemplo B (fictício)'],
      weightKg: 32,
      weighedAt: _daysAgo(20),
    ),
    DemoPatient(
      id: 'p5',
      name: 'Alice Exemplo Prado',
      birthDate: _monthsAgo(31, day: 27),
      sexLabel: 'Menina',
      guardianName: 'Responsável Exemplo A',
      avatarAsset: AppAssets.avatarMeninaTranca,
      weightKg: 12.8,
      weighedAt: _daysAgo(30),
    ),
    DemoPatient(
      id: 'p6',
      name: 'Bento Exemplo Alves',
      birthDate: _monthsAgo(62, day: 5),
      sexLabel: 'Menino',
      guardianName: 'Responsável Exemplo E',
    ),
    DemoPatient(
      id: 'p7',
      name: 'Clara Exemplo Dias',
      birthDate: _monthsAgo(20, day: 11),
      sexLabel: 'Menina',
      guardianName: 'Responsável Exemplo F',
    ),
    DemoPatient(
      id: 'p8',
      name: 'Heitor Exemplo Melo',
      birthDate: _monthsAgo(44, day: 18),
      sexLabel: 'Menino',
      guardianName: 'Responsável Exemplo G',
    ),
  ];

  static List<DemoEncounter> encounters() => <DemoEncounter>[
    DemoEncounter(
      patientId: 'p1',
      date: _monthsAgo(1),
      type: 'Consulta de rotina',
      summary:
          'Texto fictício de evolução para avaliar o layout. '
          'Não representa conduta clínica.',
    ),
    DemoEncounter(
      patientId: 'p1',
      date: _monthsAgo(3),
      type: 'Retorno',
      summary:
          'Registro de exemplo com duas linhas para testar '
          'quebra de texto e espaçamento do cartão.',
    ),
    DemoEncounter(
      patientId: 'p2',
      date: _monthsAgo(2),
      type: 'Consulta de rotina',
      summary: 'Evolução fictícia usada apenas na demonstração.',
    ),
    DemoEncounter(
      patientId: 'p3',
      date: _monthsAgo(1, day: 20),
      type: 'Primeira consulta',
      summary: 'Exemplo de primeira consulta. Conteúdo ilustrativo.',
    ),
    DemoEncounter(
      patientId: 'p1',
      date: _monthsAgo(7),
      type: 'Consulta de rotina',
      summary: 'Registro fictício mais antigo, usado no acompanhamento.',
    ),
    DemoEncounter(
      patientId: 'p4',
      date: _monthsAgo(10),
      type: 'Consulta de rotina',
      summary: 'Registro fictício. Não representa conduta clínica.',
    ),
    DemoEncounter(
      patientId: 'p5',
      date: _monthsAgo(8),
      type: 'Consulta de rotina',
      summary: 'Registro fictício. Não representa conduta clínica.',
    ),
    DemoEncounter(
      patientId: 'p6',
      date: _monthsAgo(9),
      type: 'Consulta de rotina',
      summary: 'Registro fictício. Não representa conduta clínica.',
    ),
    for (final int m in const <int>[1, 4, 6, 9])
      DemoEncounter(
        patientId: 'p7',
        date: _monthsAgo(m, day: 8),
        type: 'Consulta de rotina',
        summary: 'Registro fictício da Clínica Exemplo Dois.',
        professionalId: 'prof-b',
      ),
    DemoEncounter(
      patientId: 'p8',
      date: _monthsAgo(7, day: 3),
      type: 'Consulta por queixa',
      summary: 'Registro fictício da Clínica Exemplo Dois.',
      professionalId: 'prof-b',
    ),
  ];

  static List<DemoAppointment> appointments() {
    final DateTime d = _today();
    return <DemoAppointment>[
      DemoAppointment(
        id: 'a1',
        patientId: 'p1',
        start: d.add(const Duration(hours: 8, minutes: 30)),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.chegou,
        reason: 'Consulta de rotina (exemplo)',
        durationMinutes: 40,
      ),
      DemoAppointment(
        id: 'a2',
        patientId: 'p2',
        start: d.add(const Duration(hours: 9, minutes: 15)),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.confirmado,
        reason: 'Retorno (exemplo)',
        durationMinutes: 20,
      ),
      DemoAppointment(
        id: 'a3',
        patientId: 'p3',
        start: d.add(const Duration(hours: 10)),
        kind: DemoAppointmentKind.teleconsulta,
        status: DemoAppointmentStatus.agendado,
        reason: 'Teleconsulta (protótipo)',
      ),
      DemoAppointment(
        id: 'a4',
        patientId: 'p5',
        start: d.add(const Duration(hours: 14, minutes: 30)),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Consulta de rotina (exemplo)',
        durationMinutes: 40,
      ),
      DemoAppointment(
        id: 'a5',
        patientId: 'p4',
        start: DateTime(d.year, d.month, d.day + 1, 11),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Avaliação (exemplo)',
        durationMinutes: 40,
      ),
      DemoAppointment(
        id: 'a6',
        patientId: 'p1',
        start: DateTime(d.year, d.month, d.day + 20, 9, 30),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Retorno (exemplo)',
        durationMinutes: 20,
      ),
      DemoAppointment(
        id: 'a7',
        patientId: 'p7',
        start: DateTime(d.year, d.month, d.day + 3, 15),
        kind: DemoAppointmentKind.presencial,
        status: DemoAppointmentStatus.agendado,
        reason: 'Consulta de rotina (exemplo)',
        professionalId: 'prof-b',
        durationMinutes: 40,
      ),
    ];
  }

  static List<DemoVaccineRecord> vaccines() => <DemoVaccineRecord>[
    DemoVaccineRecord(
      patientId: 'p1',
      name: 'Vacina exemplo A',
      dose: 'Dose 1',
      status: DemoVaccineStatus.registrada,
      date: _monthsAgo(12),
    ),
    DemoVaccineRecord(
      patientId: 'p1',
      name: 'Vacina exemplo A',
      dose: 'Dose 2',
      status: DemoVaccineStatus.registrada,
      date: _monthsAgo(8),
    ),
    const DemoVaccineRecord(
      patientId: 'p1',
      name: 'Vacina exemplo B',
      dose: 'Reforço',
      status: DemoVaccineStatus.pendente,
    ),
    DemoVaccineRecord(
      patientId: 'p2',
      name: 'Vacina exemplo C',
      dose: 'Dose única',
      status: DemoVaccineStatus.registrada,
      date: _monthsAgo(20),
    ),
    DemoVaccineRecord(
      patientId: 'p3',
      name: 'Vacina exemplo A',
      dose: 'Dose 1',
      status: DemoVaccineStatus.registrada,
      date: _monthsAgo(5),
    ),
    const DemoVaccineRecord(
      patientId: 'p3',
      name: 'Vacina exemplo A',
      dose: 'Dose 2',
      status: DemoVaccineStatus.pendente,
    ),
  ];

  static const List<DemoArticle> articles = <DemoArticle>[
    DemoArticle(
      id: 'c1',
      title: 'Rotina de sono: organizando a noite',
      category: 'Sono',
      minutes: 4,
      summary: 'Artigo ilustrativo para avaliar a leitura na tela.',
    ),
    DemoArticle(
      id: 'c2',
      title: 'Introdução alimentar: primeiros passos',
      category: 'Alimentação',
      minutes: 6,
      summary:
          'Conteúdo de exemplo. O texto real passa por revisão '
          'profissional antes de ser publicado no app.',
    ),
    DemoArticle(
      id: 'c3',
      title: 'Brincadeiras que estimulam o desenvolvimento',
      category: 'Desenvolvimento',
      minutes: 5,
      summary: 'Exemplo de cartão de conteúdo com categoria e tempo.',
    ),
    DemoArticle(
      id: 'c4',
      title: 'Como se preparar para a consulta',
      category: 'Consultas',
      minutes: 3,
      summary: 'Texto fictício para demonstrar a biblioteca.',
    ),
  ];

  static List<DemoInvoice> invoices() => <DemoInvoice>[
    DemoInvoice(
      id: 'f1',
      description: 'Consulta (exemplo)',
      patientId: 'p1',
      amount: 100,
      due: _today(),
      status: DemoInvoiceStatus.pago,
    ),
    DemoInvoice(
      id: 'f2',
      description: 'Retorno (exemplo)',
      patientId: 'p2',
      amount: 100,
      due: _today().add(const Duration(days: 5)),
      status: DemoInvoiceStatus.aberto,
    ),
    DemoInvoice(
      id: 'f3',
      description: 'Consulta (exemplo)',
      patientId: 'p4',
      amount: 100,
      due: _today().subtract(const Duration(days: 9)),
      status: DemoInvoiceStatus.atrasado,
    ),
    DemoInvoice(
      id: 'f4',
      description: 'Avaliação (exemplo)',
      patientId: 'p5',
      amount: 100,
      due: _today().add(const Duration(days: 12)),
      status: DemoInvoiceStatus.aberto,
    ),
  ];
}
