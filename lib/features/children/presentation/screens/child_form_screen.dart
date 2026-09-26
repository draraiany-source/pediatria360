import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/child_avatar.dart';
import '../../../../shared/domain/entities/child.dart';
import '../providers/children_providers.dart';

/// Cadastro e edição de criança.
///
/// Campos obrigatórios são só três: nome, nascimento e sexo. O sexo não é
/// opcional porque as curvas da OMS e os cálculos de dose são estratificados
/// por ele — é parâmetro clínico, não preferência de perfil.
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({this.childId, super.key});

  final String? childId;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _allergies = TextEditingController();
  final TextEditingController _conditions = TextEditingController();
  final TextEditingController _medications = TextEditingController();
  final TextEditingController _birthWeight = TextEditingController();
  final TextEditingController _birthHeight = TextEditingController();
  final TextEditingController _guardianName = TextEditingController();
  final TextEditingController _guardianPhone = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _cpf = TextEditingController();
  final TextEditingController _insurance = TextEditingController();

  DateTime? _birthDate;
  ChildSex _sex = ChildSex.male;
  String? _bloodType;
  int? _gestationalWeeks;
  String? _photoUrl;
  bool _loaded = false;

  bool get _isEditing => widget.childId != null;

  @override
  void dispose() {
    _name.dispose();
    _allergies.dispose();
    _conditions.dispose();
    _medications.dispose();
    _birthWeight.dispose();
    _birthHeight.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _phone.dispose();
    _address.dispose();
    _cpf.dispose();
    _insurance.dispose();
    super.dispose();
  }

  void _hydrate(Child child) {
    if (_loaded) return;
    _loaded = true;
    _name.text = child.name;
    _birthDate = child.birthDate;
    _sex = child.sex;
    _bloodType = child.bloodType;
    _gestationalWeeks = child.gestationalWeeks;
    _allergies.text = child.allergies.join(', ');
    _conditions.text = child.conditions.join(', ');
    _medications.text = child.medications.join(', ');
    _birthWeight.text = child.birthWeightKg?.toString().replaceAll('.', ',') ?? '';
    _birthHeight.text = child.birthHeightCm?.toString().replaceAll('.', ',') ?? '';
    _guardianName.text = child.guardianName ?? '';
    _guardianPhone.text = child.guardianPhone ?? '';
    _phone.text = child.phone ?? '';
    _address.text = child.address ?? '';
    _cpf.text = child.cpf ?? '';
    _insurance.text = child.insurance ?? '';
    _photoUrl = child.photoUrl;
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Data de nascimento',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String? dateError = Validators.birthDate(_birthDate);
    if (dateError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dateError)));
      return;
    }

    FocusScope.of(context).unfocus();

    final Child existing = _isEditing
        ? ref.read(childProvider(widget.childId!)).valueOrNull ??
            _emptyChild()
        : _emptyChild();

    final Child toSave = Child(
      id: widget.childId ?? '',
      ownerId: existing.ownerId,
      name: _name.text.trim(),
      birthDate: _birthDate!,
      sex: _sex,
      photoUrl: _photoUrl,
      bloodType: _bloodType,
      allergies: _splitList(_allergies.text),
      conditions: _splitList(_conditions.text),
      medications: _splitList(_medications.text),
      gestationalWeeks: _gestationalWeeks,
      birthWeightKg: Parsers.decimal(_birthWeight.text),
      birthHeightCm: Parsers.decimal(_birthHeight.text),
      guardianName: _guardianName.text.trim().isEmpty
          ? existing.guardianName
          : _guardianName.text.trim(),
      guardianPhone: _guardianPhone.text.trim().isEmpty
          ? null
          : _guardianPhone.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      cpf: _cpf.text.trim().isEmpty ? null : _cpf.text.trim(),
      insurance:
          _insurance.text.trim().isEmpty ? null : _insurance.text.trim(),
      updatedAt: DateTime.now(),
    );

    final Child? saved =
        await ref.read(childrenControllerProvider.notifier).saveChild(toSave);

    if (!mounted) return;

    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Alterações salvas.' : '${saved.firstName} cadastrado.',
          ),
        ),
      );
      context.pop();
    }
  }

  Child _emptyChild() => Child(
        id: '',
        ownerId: '',
        name: '',
        birthDate: DateTime.now(),
        sex: ChildSex.male,
        updatedAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildActionState action = ref.watch(childrenControllerProvider);

    if (_isEditing) {
      final Child? child = ref.watch(childProvider(widget.childId!)).valueOrNull;
      if (child != null) _hydrate(child);
    }

    ref.listen<ChildActionState>(childrenControllerProvider,
        (ChildActionState? previous, ChildActionState next) {
      if (next.failure != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar criança' : 'Nova criança'),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancelar',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ContentBounds(
          maxWidth: 560,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  label: 'Nome',
                  controller: _name,
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.name,
                ),
                const SizedBox(height: AppSpacing.lg),
                ChildAvatarPicker(
                  selectedPhotoUrl: _photoUrl,
                  onSelected: (String? url) => setState(() => _photoUrl = url),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: AppRadius.mdAll,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de nascimento',
                      prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                      helperText: _birthDate == null
                          ? null
                          : Formatters.pediatricAge(_birthDate!),
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Selecionar'
                          : Formatters.date(_birthDate!),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Sexo', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ChildSex>(
                  segments: ChildSex.values
                      .map(
                        (ChildSex s) => ButtonSegment<ChildSex>(
                          value: s,
                          label: Text(s.label),
                          icon: Icon(
                            s == ChildSex.male
                                ? Icons.male_rounded
                                : Icons.female_rounded,
                          ),
                        ),
                      )
                      .toList(),
                  selected: <ChildSex>{_sex},
                  onSelectionChanged: (Set<ChildSex> value) =>
                      setState(() => _sex = value.first),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'As curvas de crescimento e os cálculos de dose usam esta '
                  'informação.',
                  style: theme.textTheme.bodySmall,
                ),
                const SectionHeader(
                  title: 'Contato e identificação',
                  eyebrow: 'Cadastro',
                ),
                AppTextField(
                  label: 'Responsável',
                  controller: _guardianName,
                  prefixIcon: Icons.family_restroom_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Telefone do responsável',
                  controller: _guardianPhone,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: Masks.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Telefone de contato',
                  controller: _phone,
                  prefixIcon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: Masks.phone,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'CPF',
                  controller: _cpf,
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: Masks.cpf,
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? null : Validators.cpf(v),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Endereço',
                  controller: _address,
                  prefixIcon: Icons.home_outlined,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Convênio',
                  controller: _insurance,
                  prefixIcon: Icons.health_and_safety_outlined,
                  hint: 'Particular, Unimed, Bradesco…',
                ),
                const SectionHeader(
                  title: 'Nascimento',
                  eyebrow: 'Opcional',
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Peso ao nascer',
                        controller: _birthWeight,
                        hint: '3,4',
                        suffix: const Padding(
                          padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                          child: Text('kg'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: Masks.decimal,
                        validator: (String? v) => (v == null || v.isEmpty)
                            ? null
                            : Validators.weightKg(v),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Comprimento',
                        controller: _birthHeight,
                        hint: '49',
                        suffix: const Padding(
                          padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                          child: Text('cm'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: Masks.decimal,
                        validator: (String? v) => (v == null || v.isEmpty)
                            ? null
                            : Validators.heightCm(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<int?>(
                  value: _gestationalWeeks,
                  decoration: const InputDecoration(
                    labelText: 'Semanas de gestação ao nascer',
                    prefixIcon: Icon(Icons.pregnant_woman_outlined, size: 20),
                    helperText: 'Abaixo de 37 semanas, o app passa a usar '
                        'idade corrigida nas curvas.',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      child: Text('Não informado'),
                    ),
                    for (int w = 24; w <= 42; w++)
                      DropdownMenuItem<int?>(
                        value: w,
                        child: Text(
                          '$w semanas${w < 37 ? '  ·  prematuro' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (int? v) => setState(() => _gestationalWeeks = v),
                ),
                if (_gestationalWeeks != null && _gestationalWeeks! < 37) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.10),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'As curvas usarão idade corrigida até os 2 anos. '
                            'O calendário de vacinas segue a idade real — '
                            'prematuros não devem atrasar a proteção.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SectionHeader(title: 'Saúde', eyebrow: 'Opcional'),
                DropdownButtonFormField<String?>(
                  value: _bloodType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo sanguíneo',
                    prefixIcon: Icon(Icons.bloodtype_outlined, size: 20),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      child: Text('Não informado'),
                    ),
                    for (final String type in <String>[
                      'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
                    ])
                      DropdownMenuItem<String?>(
                        value: type,
                        child: Text(type),
                      ),
                  ],
                  onChanged: (String? v) => setState(() => _bloodType = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Alergias',
                  controller: _allergies,
                  hint: 'Amendoim, dipirona',
                  helper: 'Separe por vírgula.',
                  prefixIcon: Icons.warning_amber_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Condições de saúde',
                  controller: _conditions,
                  hint: 'Asma, refluxo',
                  helper: 'Separe por vírgula.',
                  prefixIcon: Icons.medical_information_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Medicações em uso',
                  controller: _medications,
                  hint: 'Salbutamol, vitamina D',
                  helper: 'Uso contínuo. Separe por vírgula.',
                  prefixIcon: Icons.medication_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: _isEditing ? 'Salvar alterações' : 'Cadastrar',
                  isLoading: action.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
