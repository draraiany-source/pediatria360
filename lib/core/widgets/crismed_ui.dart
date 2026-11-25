import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Caminho do asset da mascote. Troque o arquivo mantendo este nome.
const String kTiaCrisAsset = 'assets/illustrations/tia_cris.svg';

/// Marca Crismed: coração com estetoscópio.
class CrismedLogo extends StatelessWidget {
  const CrismedLogo({this.size = 42, this.onDark = false, super.key});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color fg = onDark ? Colors.white : AppColors.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : AppColors.softLilac,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.monitor_heart_rounded, color: fg, size: size * 0.58),
    );
  }
}

/// Ilustração da Tia Cris. Se o SVG não carregar, mostra um desenho reserva.
class TiaCrisMascot extends StatelessWidget {
  const TiaCrisMascot({this.height = 132, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: SvgPicture.asset(
            kTiaCrisAsset,
            height: height,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const _TiaCrisFallback(),
          ),
        ),
        Text(
          'Tia Cris',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TiaCrisFallback extends StatelessWidget {
  const _TiaCrisFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.face_3_rounded, color: Colors.white, size: 72);
  }
}

class CrismedCard extends StatelessWidget {
  const CrismedCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Widget inner = Padding(padding: padding, child: child);
    return Material(
      color: color ?? Colors.white,
      elevation: 1.5,
      shadowColor: AppColors.navy.withValues(alpha: 0.18),
      borderRadius: AppRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? inner
          : InkWell(onTap: onTap, borderRadius: AppRadius.xlAll, child: inner),
    );
  }
}

class CrismedIconBubble extends StatelessWidget {
  const CrismedIconBubble({
    required this.icon,
    required this.color,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class CrismedSampleBanner extends StatelessWidget {
  const CrismedSampleBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softOrange,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.honey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.science_outlined,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ??
                  'Dados de exemplo — esta sessão não tem registros reais deste módulo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedPageHeader extends StatelessWidget {
  const CrismedPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.onAi,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onAi;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 720;
        final Widget titles = Row(
          children: <Widget>[
            CrismedIconBubble(icon: icon, color: AppColors.brand, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final Widget buttons = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: onAi,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('IA da Tia Cris'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            if (primaryLabel != null)
              FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(primaryLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6A45B0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
          ],
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[titles, const SizedBox(height: 12), buttons],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: titles),
            buttons,
          ],
        );
      },
    );
  }
}

class CrismedKpi extends StatelessWidget {
  const CrismedKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.positive = true,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;
  final bool positive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CrismedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CrismedIconBubble(icon: icon, color: color, size: 36),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (positive ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    delta!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: positive ? AppColors.tealDeep : AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedPillTabs extends StatelessWidget {
  const CrismedPillTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(labels[i]),
              selected: i == index,
              onSelected: (_) => onChanged(i),
              selectedColor: AppColors.brand,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: i == index ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: i == index ? AppColors.brand : AppColors.line,
              ),
              shape: const StadiumBorder(),
              showCheckmark: false,
            ),
          ],
        ],
      ),
    );
  }
}

class CrismedPatientCard extends StatelessWidget {
  const CrismedPatientCard({
    required this.name,
    required this.age,
    required this.birth,
    this.weight,
    this.height,
    this.bmi,
    this.exampleMetrics = false,
    super.key,
  });

  final String name;
  final String age;
  final String birth;
  final String? weight;
  final String? height;
  final String? bmi;
  final bool exampleMetrics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CrismedCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.softPink,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.raspberry,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  '$age · nasc. $birth',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                if (exampleMetrics)
                  Text(
                    'Peso, estatura e IMC ilustrativos',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (weight != null || height != null || bmi != null)
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (weight != null) _Metric(label: 'Peso', value: weight!),
                if (height != null) _Metric(label: 'Estatura', value: height!),
                if (bmi != null) _Metric(label: 'IMC', value: bmi!),
              ],
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softLilac,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class CrismedActionSpec {
  const CrismedActionSpec({
    required this.label,
    required this.icon,
    this.primary = false,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;
}

class CrismedActionBar extends StatelessWidget {
  const CrismedActionBar({required this.actions, super.key});

  final List<CrismedActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final CrismedActionSpec action in actions) ...<Widget>[
                action.primary
                    ? FilledButton.icon(
                        onPressed: action.onPressed,
                        icon: Icon(action.icon, size: 18),
                        label: Text(action.label),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.action,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 42),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: action.onPressed,
                        icon: Icon(action.icon, size: 18),
                        label: Text(action.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CrismedClinicFooter extends StatelessWidget {
  const CrismedClinicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: <Widget>[
          Text('Clínica Crismed (exemplo)', style: style),
          Text('CNPJ 00.000.000/0001-00 (exemplo)', style: style),
          Text('Ambiente de demonstração', style: style),
          Text('LGPD', style: style),
          Text('${AppConfig.appName} 1.0.0', style: style),
        ],
      ),
    );
  }
}

class CrismedSectionTitle extends StatelessWidget {
  const CrismedSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Página padrão: banner opcional, conteúdo rolável e barra de ações.
/// Paciente ilustrativo das referências. Só aparece com o aviso de exemplo.
class CrismedDemoPatient {
  const CrismedDemoPatient._();

  static const String name = 'Enzo Gabriel';
  static const String age = '5 anos e 2 meses';
  static const String birth = '20/08/2021';
  static const String weight = '18,4 kg';
  static const String height = '112 cm';
  static const String bmi = '14,7';
  static const String percentile = 'P62';
}

class CrismedPatientBanner extends StatelessWidget {
  const CrismedPatientBanner({
    required this.name,
    required this.age,
    this.birth,
    this.weight,
    this.height,
    this.bmi,
    this.percentile,
    this.example = false,
    this.onChart,
    super.key,
  });

  final String name;
  final String age;
  final String? birth;
  final String? weight;
  final String? height;
  final String? bmi;
  final String? percentile;
  final bool example;
  final VoidCallback? onChart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CrismedCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.softLilac,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  birth == null ? age : '$age  ·  Nasc.: $birth',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                if (example)
                  Text(
                    'Dados de exemplo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (weight != null)
            _PillMetric(
              icon: Icons.monitor_weight_outlined,
              label: 'Peso',
              value: weight!,
              extra: percentile,
            ),
          if (height != null) ...<Widget>[
            const SizedBox(width: 8),
            _PillMetric(
              icon: Icons.height_rounded,
              label: 'Estatura',
              value: height!,
              extra: percentile,
            ),
          ],
          if (bmi != null) ...<Widget>[
            const SizedBox(width: 8),
            _PillMetric(
              icon: Icons.speed_rounded,
              label: 'IMC',
              value: bmi!,
              extra: percentile,
            ),
          ],
          if (onChart != null) ...<Widget>[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onChart,
              icon: const Icon(Icons.folder_shared_outlined, size: 16),
              label: const Text('Ver Prontuário'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillMetric extends StatelessWidget {
  const _PillMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.extra,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softLilac,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
              Text(
                extra == null ? value : '$value  $extra',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CrismedCheckLine extends StatelessWidget {
  const CrismedCheckLine(
    this.label, {
    this.trailing,
    this.ok = true,
    super.key,
  });

  final String label;
  final String? trailing;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 16,
            color: ok ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ok ? AppColors.inkMuted : AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}

class CrismedScaffold extends StatelessWidget {
  const CrismedScaffold({
    required this.body,
    this.actions = const <CrismedActionSpec>[],
    super.key,
  });

  final Widget body;
  final List<CrismedActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: <Widget>[
          Expanded(child: body),
          if (actions.isNotEmpty) CrismedActionBar(actions: actions),
        ],
      ),
    );
  }
}

class CrismedBody extends StatelessWidget {
  const CrismedBody({
    required this.children,
    this.sample = false,
    this.sampleMessage,
    super.key,
  });

  final List<Widget> children;
  final bool sample;
  final String? sampleMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: <Widget>[
        if (sample) CrismedSampleBanner(message: sampleMessage),
        ...children,
      ],
    );
  }
}

void crismedToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Grade responsiva de filhos com largura mínima.
class CrismedWrap extends StatelessWidget {
  const CrismedWrap({
    required this.children,
    this.minWidth = 180,
    this.spacing = 12,
    super.key,
  });

  final List<Widget> children;
  final double minWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double max = constraints.maxWidth;
        final int columns = (max / minWidth).floor().clamp(1, 6);
        final double width = (max - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

String crismedHour(DateTime value) {
  final String h = value.hour.toString().padLeft(2, '0');
  final String m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
