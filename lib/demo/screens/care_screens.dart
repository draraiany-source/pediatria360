import 'package:flutter/material.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/child_avatar.dart';
import '../../core/widgets/clinical_ui.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

/// Vacinacao: registros ilustrativos por paciente. Nao e calendario oficial.
class DemoVaccinesScreen extends StatefulWidget {
  const DemoVaccinesScreen({super.key, this.initialPatientId});

  final String? initialPatientId;

  @override
  State<DemoVaccinesScreen> createState() => _DemoVaccinesScreenState();
}

class _DemoVaccinesScreenState extends State<DemoVaccinesScreen> {
  String? _patientId;

  @override
  void initState() {
    super.initState();
    final List<DemoPatient> visible = demoSession.visiblePatients;
    final bool valid = visible
        .any((DemoPatient p) => p.id == widget.initialPatientId);
    _patientId = valid
        ? widget.initialPatientId
        : (visible.isEmpty ? null : visible.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final List<DemoPatient> patients = demoSession.visiblePatients;
    final DemoPatient? p = _patientId == null
        ? null
        : demoSession.patientById(_patientId!);
    final List<DemoVaccineRecord> records = p == null
        ? const <DemoVaccineRecord>[]
        : demoSession.vaccines
            .where((DemoVaccineRecord r) => r.patientId == p.id)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Vacinação')),
      body: DemoLoader(
        label: 'Carregando vacinas...',
        builder: (BuildContext context) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoNotice(
                    icon: Icons.science_outlined,
                    color: AppColors.warning,
                    text: 'Registros ilustrativos com nomes genericos. Não use '
                        'como referência de calendário vacinal: no app real '
                        'o calendário depende de fonte oficial e validação '
                        'profissional.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (patients.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: DemoEmpty(
                        title: 'Nenhuma criança',
                        message: 'Cadastre uma criança para ver as vacinas.',
                        pose: CapiPose.bracosAbertos,
                      ),
                    )
                  else ...<Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: _patientId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Paciente'),
                      items: <DropdownMenuItem<String>>[
                        for (final DemoPatient x in patients)
                          DropdownMenuItem<String>(
                            value: x.id,
                            child: Text(x.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (String? v) => setState(() => _patientId = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (p != null)
                      Row(
                        children: <Widget>[
                          ChildAvatarImage(
                            name: p.name,
                            seed: p.id,
                            photoUrl: p.avatarAsset == null
                                ? null
                                : ChildAvatarRef.encode(p.avatarAsset!),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(p.name,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (records.isEmpty)
                      const SizedBox(
                        height: 300,
                        child: DemoEmpty(
                          title: 'Sem registros',
                          message: 'Nenhuma vacina registrada para esta '
                              'criança na demonstração.',
                        ),
                      )
                    else
                      for (final DemoVaccineRecord r in records)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  r.status == DemoVaccineStatus.registrada
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                                  color: r.status ==
                                          DemoVaccineStatus.registrada
                                      ? AppColors.tealDeep
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(r.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text(
                                        r.date == null
                                            ? r.dose
                                            : '${r.dose} - ${demoDate(r.date!)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                ClinicalBadge(
                                  label: r.status ==
                                          DemoVaccineStatus.registrada
                                      ? 'Registrada'
                                      : 'Pendente',
                                  color: r.status ==
                                          DemoVaccineStatus.registrada
                                      ? AppColors.tealDeep
                                      : AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () => showDemoSnack(context,
                          'Registrar vacina só pode ser testado na versão autenticada.'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Registrar vacina'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Telemedicina: prototipo visual. Video nao funciona de ponta a ponta.
class DemoTelemedicineScreen extends StatelessWidget {
  const DemoTelemedicineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DemoAppointment> tele = demoSession.appointments
        .where((DemoAppointment a) =>
            a.kind == DemoAppointmentKind.teleconsulta &&
            demoSession.visiblePatients
                .any((DemoPatient p) => p.id == a.patientId))
        .toList();
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text('Telemedicina', overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: AppSpacing.sm),
            DemoTag('Protótipo'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          DemoContent(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.videocam_off_outlined,
                  color: AppColors.danger,
                  text: 'Videochamada INDISPONÍVEL. Esta tela é um protótipo '
                      'de layout: a sala de vídeo ainda não funciona de ponta '
                      'a ponta e também está desativada no app real.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: AppRadius.xlAll,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.videocam_off_outlined,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Área do vídeo (indisponível)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _RoundButton(Icons.mic_off_outlined, 'Microfone'),
                    _RoundButton(Icons.videocam_off_outlined, 'Camera'),
                    _RoundButton(Icons.call_end_rounded, 'Encerrar',
                        color: AppColors.danger),
                  ],
                ),
                const DemoSectionTitle('Teleconsultas agendadas (fictício)'),
                if (tele.isEmpty)
                  const SizedBox(
                    height: 260,
                    child: DemoEmpty(
                      title: 'Nenhuma teleconsulta',
                      message: 'Não há teleconsultas para este perfil.',
                      pose: CapiPose.boasVindas,
                    ),
                  )
                else
                  for (final DemoAppointment a in tele)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.videocam_outlined,
                                    color: AppColors.brand),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    '${demoDate(a.start)} às ${demoTime(a.start)} - '
                                    '${demoSession.patients.firstWhere((DemoPatient p) => p.id == a.patientId).name}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: null,
                                child: Text('Entrar (indisponível)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(this.icon, this.label, {this.color = AppColors.inkMuted});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: null,
          tooltip: '$label (indisponível)',
          icon: Icon(icon, color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
