import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/child_avatar.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../../shared/clinical/lab_results.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

String? _avatarUrl(DemoPatient p) =>
    p.avatarAsset == null ? null : ChildAvatarRef.encode(p.avatarAsset!);

/// Lista e busca de pacientes (ou "Minhas criancas" para o responsavel).
class DemoPatientsScreen extends StatefulWidget {
  const DemoPatientsScreen({super.key});

  @override
  State<DemoPatientsScreen> createState() => _DemoPatientsScreenState();
}

class _DemoPatientsScreenState extends State<DemoPatientsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuardian = demoSession.profile == DemoProfile.responsavel;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(isGuardian ? 'Minhas crianças' : 'Pacientes'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/pacientes/novo'),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(isGuardian ? 'Adicionar criança' : 'Novo paciente'),
      ),
      body: DemoLoader(
        label: 'Carregando pacientes...',
        builder: (BuildContext context) => ListenableBuilder(
          listenable: demoSession,
          builder: (BuildContext context, _) {
            final List<DemoPatient> all = demoSession.visiblePatients;
            final String q = _query.trim().toLowerCase();
            final List<DemoPatient> list = q.isEmpty
                ? all
                : all
                      .where(
                        (DemoPatient p) => p.name.toLowerCase().contains(q),
                      )
                      .toList();
            return DemoContent(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: TextField(
                      controller: _search,
                      onChanged: (String v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? DemoEmpty(
                            title: q.isEmpty
                                ? 'Nenhum paciente ainda'
                                : 'Ninguém encontrado',
                            message: q.isEmpty
                                ? 'Cadastre o primeiro para começar.'
                                : 'Nenhum nome contém "$_query".',
                            pose: q.isEmpty
                                ? CapiPose.bracosAbertos
                                : CapiPose.lupa,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              96,
                            ),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (BuildContext context, int i) =>
                                _PatientTile(patient: list[i]),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});

  final DemoPatient patient;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/pacientes/${patient.id}'),
      child: Row(
        children: <Widget>[
          ChildAvatarImage(
            name: patient.name,
            seed: patient.id,
            photoUrl: _avatarUrl(patient),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${patient.ageLabel} - ${patient.sexLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (patient.allergies.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: ClinicalBadge(label: 'Alergia', color: AppColors.danger),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// Resumo do paciente com atalhos para prontuario e vacinas.
class DemoPatientDetailScreen extends StatelessWidget {
  const DemoPatientDetailScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Paciente')),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message:
                  'Este registro não existe ou não pertence ao perfil '
                  'atual.',
              actionLabel: 'Voltar para a lista',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final bool isGuardian = demoSession.profile == DemoProfile.responsavel;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(title: Text(p.name)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Row(
                        children: <Widget>[
                          ChildAvatarImage(
                            name: p.name,
                            seed: p.id,
                            photoUrl: _avatarUrl(p),
                            radius: 34,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  p.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text('${p.ageLabel} - ${p.sexLabel}'),
                                Text(
                                  'Nascimento: ${demoDate(p.birthDate)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Responsável: ${p.guardianName}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (demoSession.canSeeClinicalRecord)
                                  Text(
                                    p.weightKg == null
                                        ? 'Peso: não registrado'
                                        : 'Peso: ${formatDoseNumber(p.weightKg!)} kg '
                                              '(${demoDate(p.weighedAt!)})',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.allergies.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      DemoNotice(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        text: 'Alergias (fictício): ${p.allergies.join(', ')}',
                      ),
                    ],
                    const DemoSectionTitle('Ações'),
                    if (demoSession.canUseClinicalTools)
                      _ActionTile(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Iniciar consulta',
                        subtitle: 'Consulta, avaliação, conduta e documentos',
                        highlight: true,
                        onTap: () {
                          final DemoConsultation c = demoSession
                              .startConsultation(p.id);
                          context.go('/pacientes/${p.id}/consulta/${c.id}');
                        },
                      ),
                    if (demoSession.canSeeClinicalRecord)
                      _ActionTile(
                        icon: Icons.description_outlined,
                        title: 'Prontuário',
                        subtitle: 'Consultas, evoluções e documentos',
                        onTap: () =>
                            context.go('/pacientes/${p.id}/prontuario'),
                      ),
                    if (demoSession.canUseClinicalTools) ...<Widget>[
                      _ActionTile(
                        icon: Icons.folder_open_outlined,
                        title: 'Documentos',
                        subtitle:
                            '${demoSession.documentsFor(p.id).length} no histórico',
                        onTap: () =>
                            context.go('/pacientes/${p.id}/documentos'),
                      ),
                      _ActionTile(
                        icon: Icons.calculate_outlined,
                        title: 'Calculadora de doses',
                        subtitle: p.weightKg == null
                            ? 'Sem peso registrado: cálculo bloqueado'
                            : 'Peso ${formatDoseNumber(p.weightKg!)} kg em '
                                  '${demoDate(p.weighedAt!)}',
                        onTap: () =>
                            context.go('/calculadora?paciente=${p.id}'),
                      ),
                    ],
                    if (demoSession.canSeeGrowth)
                      _ActionTile(
                        icon: Icons.show_chart_rounded,
                        title: 'Crescimento',
                        subtitle: demoSession.canEditGrowth
                            ? 'Curvas da OMS, escore Z, percentil e PDF'
                            : 'Curvas de peso e altura (visão simples)',
                        onTap: () =>
                            context.go('/pacientes/${p.id}/crescimento'),
                      ),
                    if (isGuardian)
                      _ActionTile(
                        icon: Icons.event_note_outlined,
                        title: 'Rotina e diário',
                        subtitle: 'Calendário, diário e resumo para o pediatra',
                        highlight: true,
                        onTap: () => context.go('/rotina/${p.id}'),
                      ),
                    if (demoSession.profile == DemoProfile.profissional)
                      if (demoSession.routineSharedWith(p.id)) ...<Widget>[
                        _ActionTile(
                          icon: Icons.summarize_outlined,
                          title: 'Resumos enviados pela família',
                          subtitle:
                              '${demoSession.sharedSummariesFor(p.id).length} '
                              'resumo(s) - informado pela família',
                          onTap: () =>
                              context.go('/rotina/${p.id}/resumos'),
                        ),
                        _ActionTile(
                          icon: Icons.event_note_outlined,
                          title: 'Rotina e diário da família',
                          subtitle: 'Calendário e diário, somente leitura',
                          onTap: () => context.go('/rotina/${p.id}'),
                        ),
                      ] else
                        _ActionTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Rotina e diário da família',
                          subtitle: 'A família não compartilhou a rotina',
                          onTap: () => showDemoSnack(
                            context,
                            'A família ainda não autorizou o compartilhamento '
                            'da rotina com a clínica.',
                          ),
                        ),
                    if (demoSession.canUseClinicalTools) ...<Widget>[
                      _ActionTile(
                        icon: Icons.biotech_outlined,
                        title: 'Exames laboratoriais',
                        subtitle: () {
                          final int pending = demoSession
                              .labsFor(p.id)
                              .where((LabResult r) => r.isPending)
                              .length;
                          final int total = demoSession
                              .labsFor(p.id)
                              .where((LabResult r) => r.inRecord)
                              .length;
                          return '$total conferidos'
                              '${pending == 0 ? '' : ' - $pending pendente(s) de conferência'}';
                        }(),
                        onTap: () => context.go('/pacientes/${p.id}/exames'),
                      ),
                      _ActionTile(
                        icon: Icons.medication_liquid_outlined,
                        title: 'Suplementação do paciente',
                        subtitle: 'Decisões por nutriente, exames e receituário',
                        onTap: () =>
                            context.go('/pacientes/${p.id}/suplementacao'),
                      ),
                    ],
                    if (demoSession.canOpen(DemoModule.vacinacao))
                      _ActionTile(
                        icon: Icons.vaccines_outlined,
                        title: 'Vacinação',
                        subtitle: 'Registros ilustrativos',
                        onTap: () => context.go('/vacinacao?paciente=${p.id}'),
                      ),
                    if (isGuardian)
                      _ActionTile(
                        icon: Icons.face_retouching_natural_outlined,
                        title: 'Avatar ilustrado (opcional)',
                        subtitle: p.avatarAsset == null
                            ? 'Sem avatar - usando iniciais'
                            : 'Avatar escolhido pelo responsável',
                        onTap: () => _pickAvatar(context, p),
                      ),
                    if (!demoSession.canSeeClinicalRecord && !isGuardian)
                      const DemoNotice(
                        icon: Icons.shield_outlined,
                        text:
                            'Este perfil vê apenas o cadastro. Prontuário e '
                            'restrito aos profissionais de saúde.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(BuildContext context, DemoPatient p) async {
    String? selected = _avatarUrl(p);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ChildAvatarPicker(
                  selectedPhotoUrl: selected,
                  onSelected: (String? v) => setSheet(() => selected = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheet).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          demoSession.setAvatar(
                            p,
                            ChildAvatarRef.pathFrom(selected),
                          );
                          Navigator.of(sheet).pop();
                          showDemoSnack(
                            context,
                            'Avatar atualizado só nesta demonstração.',
                          );
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Ação principal do profissional, em cor sólida.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Widget row = Row(
      children: <Widget>[
        Icon(icon, color: highlight ? Colors.white : AppColors.brand),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: highlight
                    ? t.titleSmall?.copyWith(color: Colors.white)
                    : t.titleSmall,
              ),
              Text(
                subtitle,
                style: highlight
                    ? t.bodySmall?.copyWith(color: const Color(0xFFDCE6FF))
                    : t.bodySmall,
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: highlight ? Colors.white : null,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: highlight
          ? Material(
              color: AppColors.brand,
              borderRadius: AppRadius.xlAll,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.xlAll,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: row,
                ),
              ),
            )
          : PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: onTap,
              child: row,
            ),
    );
  }
}

/// Cadastro com validacao e aviso ao sair com alteracoes nao salvas.
class DemoPatientFormScreen extends StatefulWidget {
  const DemoPatientFormScreen({super.key});

  @override
  State<DemoPatientFormScreen> createState() => _DemoPatientFormScreenState();
}

class _DemoPatientFormScreenState extends State<DemoPatientFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _guardian = TextEditingController();
  DateTime? _birth;
  String? _sex;
  String? _avatar;
  bool _saving = false;

  bool get _dirty =>
      _name.text.isNotEmpty ||
      _guardian.text.isNotEmpty ||
      _birth != null ||
      _sex != null ||
      _avatar != null;

  bool get _isGuardian => demoSession.profile == DemoProfile.responsavel;

  @override
  void dispose() {
    _name.dispose();
    _guardian.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Descartar cadastro?'),
        content: const Text('Os dados preenchidos serão perdidos.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _leave() async {
    if (await _confirmDiscard() && mounted) context.go('/pacientes');
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _birth ?? now,
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _save() async {
    final bool ok = _form.currentState!.validate();
    if (_birth == null) {
      showDemoSnack(context, 'Informe a data de nascimento.');
      return;
    }
    if (!ok) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final DemoPatient p = demoSession.addPatient(
      name: _name.text.trim(),
      birthDate: _birth!,
      sexLabel: _sex!,
      guardianName: _guardian.text.trim(),
      avatarAsset: ChildAvatarRef.pathFrom(_avatar),
    );
    showDemoSnack(
      context,
      '${p.name} adicionado nesta demonstração (some ao recarregar).',
    );
    context.go('/pacientes/${p.id}');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(_isGuardian ? 'Adicionar criança' : 'Novo paciente'),
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close_rounded),
            onPressed: _leave,
          ),
        ),
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoNotice(
                      text:
                          'Use apenas nomes fictícios. O cadastro fica só '
                          'nesta aba e não é enviado a nenhum servidor.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                      ),
                      validator: (String? v) {
                        final String t = (v ?? '').trim();
                        if (t.isEmpty) return 'Informe o nome.';
                        if (!t.contains(' ')) {
                          return 'Informe nome e sobrenome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        _birth == null
                            ? 'Data de nascimento *'
                            : 'Nascimento: ${demoDate(_birth!)}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      container: true,
                      child: DropdownButtonFormField<String>(
                        initialValue: _sex,
                        decoration: const InputDecoration(labelText: 'Sexo *'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'Menina',
                            child: Text('Feminino'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Menino',
                            child: Text('Masculino'),
                          ),
                        ],
                        onChanged: (String? v) => setState(() => _sex = v),
                        validator: (String? v) =>
                            v == null ? 'Selecione o sexo.' : null,
                      ),
                    ),
                    if (!_isGuardian) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _guardian,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome do responsável *',
                        ),
                        validator: (String? v) => (v ?? '').trim().isEmpty
                            ? 'Informe o responsável.'
                            : null,
                      ),
                    ],
                    if (_isGuardian) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      ChildAvatarPicker(
                        selectedPhotoUrl: _avatar,
                        onSelected: (String? v) => setState(() => _avatar = v),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _leave,
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
