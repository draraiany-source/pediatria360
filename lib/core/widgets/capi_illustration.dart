import 'package:flutter/material.dart';

import '../config/app_assets.dart';
import '../config/capi_pose.dart';

/// Ilustracao do Capi — apenas welcome, vazio e sucesso (nao sobre dados clinicos).
class CapiIllustration extends StatelessWidget {
  const CapiIllustration({
    required this.pose,
    super.key,
    this.size = 160,
    this.semanticLabel = 'Capi, mascote do Pediatria 360',
  });

  final CapiPose pose;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Sem container, os textos vizinhos seriam lidos como parte da imagem.
    return Semantics(
      container: true,
      label: semanticLabel,
      image: true,
      child: Image.asset(
        AppAssets.capiForPose(pose),
        excludeFromSemantics: true,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            Icon(Icons.pets_rounded, size: size * 0.4, color: Colors.blue),
      ),
    );
  }
}
