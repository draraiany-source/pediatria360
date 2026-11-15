import 'package:flutter/material.dart';

import '../config/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Codificacao de avatar local em [photoUrl] (`asset:` + caminho completo).
class ChildAvatarRef {
  const ChildAvatarRef._();

  static const String assetPrefix = 'asset:';

  static bool isAsset(String? photoUrl) =>
      photoUrl != null && photoUrl.startsWith(assetPrefix);

  static String? pathFrom(String? photoUrl) {
    if (!isAsset(photoUrl)) return null;
    return photoUrl!.substring(assetPrefix.length);
  }

  static String encode(String assetPath) => '$assetPrefix$assetPath';
}

/// Avatar circular: asset ilustrado, foto de rede ou iniciais.
class ChildAvatarImage extends StatelessWidget {
  const ChildAvatarImage({
    required this.name,
    required this.seed,
    super.key,
    this.photoUrl,
    this.radius = 22,
  });

  final String name;
  final String seed;
  final String? photoUrl;
  final double radius;

  String get _initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ImageProvider? get _imageProvider {
    final String? url = photoUrl;
    if (url == null || url.isEmpty) return null;
    final String? assetPath = ChildAvatarRef.pathFrom(url);
    if (assetPath != null) return AssetImage(assetPath);
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider = _imageProvider;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.avatarFor(seed),
      backgroundImage: provider,
      child: provider == null
          ? Text(
              _initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            )
          : null,
    );
  }
}

/// Grade de avatares ilustrados + opcao de nenhum (sem atribuicao automatica).
class ChildAvatarPicker extends StatelessWidget {
  const ChildAvatarPicker({
    required this.selectedPhotoUrl,
    required this.onSelected,
    super.key,
  });

  final String? selectedPhotoUrl;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? selectedAsset = ChildAvatarRef.pathFrom(selectedPhotoUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Avatar ilustrado (opcional)',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Escolha um desenho ou deixe sem avatar. O nome da crianca '
          'continua visivel em todas as telas.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _PickerTile(
              label: 'Sem avatar',
              selected: selectedPhotoUrl == null || selectedPhotoUrl!.isEmpty,
              onTap: () => onSelected(null),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.block_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final String asset in AppAssets.childAvatarAssets)
              _PickerTile(
                label: _shortLabel(asset),
                selected: selectedAsset == asset,
                onTap: () => onSelected(ChildAvatarRef.encode(asset)),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage(asset),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _shortLabel(String assetPath) {
    final String base = assetPath.split('/').last.replaceAll('.png', '');
    return base.replaceFirst('avatar_', '').replaceAll('_', ' ');
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          width: 76,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              child,
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
