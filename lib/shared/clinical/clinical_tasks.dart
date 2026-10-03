/// Tarefas e lembretes de acompanhamento do profissional.
library;

enum TaskKind {
  tarefa('Tarefa'),
  acompanhamento('Lembrete de acompanhamento');

  const TaskKind(this.label);

  final String label;
}

enum TaskDue {
  atrasada('Atrasada'),
  hoje('Para hoje'),
  proxima('Próxima'),
  semData('Sem data'),
  concluida('Concluída');

  const TaskDue(this.label);

  final String label;
}

class ClinicalTask {
  ClinicalTask({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.createdBy,
    this.due,
    this.patientId,
    this.consultationId,
  });

  final String id;

  /// Conta do profissional dona da lista.
  final String ownerId;
  final String title;
  final TaskKind kind;
  final DateTime createdAt;
  final String createdBy;

  /// Só a data importa.
  final DateTime? due;
  final String? patientId;
  final String? consultationId;
  DateTime? doneAt;
  String? doneBy;

  bool get done => doneAt != null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

TaskDue taskDue(ClinicalTask t, DateTime now) {
  if (t.done) return TaskDue.concluida;
  if (t.due == null) return TaskDue.semData;
  final DateTime due = _day(t.due!);
  final DateTime today = _day(now);
  if (due.isBefore(today)) return TaskDue.atrasada;
  if (due == today) return TaskDue.hoje;
  return TaskDue.proxima;
}

/// Abertas primeiro (atrasadas, hoje, próximas, sem data); depois as
/// concluídas, da mais recente para a mais antiga.
List<ClinicalTask> sortTasks(Iterable<ClinicalTask> tasks) {
  final List<ClinicalTask> open =
      tasks.where((ClinicalTask t) => !t.done).toList()
        ..sort((ClinicalTask a, ClinicalTask b) {
          if (a.due == null && b.due == null) {
            return a.createdAt.compareTo(b.createdAt);
          }
          if (a.due == null) return 1;
          if (b.due == null) return -1;
          return a.due!.compareTo(b.due!);
        });
  final List<ClinicalTask> closed =
      tasks.where((ClinicalTask t) => t.done).toList()..sort(
        (ClinicalTask a, ClinicalTask b) => b.doneAt!.compareTo(a.doneAt!),
      );
  return <ClinicalTask>[...open, ...closed];
}

List<String> validateTask({
  required String title,
  required DateTime? due,
  required DateTime now,
}) => <String>[
  if (title.trim().isEmpty) 'Descreva a tarefa.',
  if (title.trim().length > 200) 'Use até 200 caracteres.',
  if (due != null && _day(due).isBefore(_day(now)))
    'A data não pode estar no passado.',
];
