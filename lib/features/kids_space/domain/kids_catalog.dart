/// Catalogo do Espaco Kids 360 — jogos reais, sem acesso clinico.
enum KidsAgeBand { toddler, preschool, school }

enum KidsGameId {
  memory,
  colorsShapes,
  numbersLetters,
  puzzle,
  attention,
  hygieneFood,
}

class KidsGameInfo {
  const KidsGameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.minAgeBand,
    required this.caption,
  });

  final KidsGameId id;
  final String title;
  final String subtitle;
  final KidsAgeBand minAgeBand;
  final String caption;

  static const List<KidsGameInfo> all = <KidsGameInfo>[
    KidsGameInfo(
      id: KidsGameId.memory,
      title: 'Memoria do Ursinho',
      subtitle: 'Encontre os pares de figuras',
      minAgeBand: KidsAgeBand.toddler,
      caption: 'Vamos achar os pares iguais!',
    ),
    KidsGameInfo(
      id: KidsGameId.colorsShapes,
      title: 'Cores e formas',
      subtitle: 'Combine cada forma com a cor',
      minAgeBand: KidsAgeBand.toddler,
      caption: 'Toque na cor certa para cada forma!',
    ),
    KidsGameInfo(
      id: KidsGameId.numbersLetters,
      title: 'Numeros e letras',
      subtitle: 'Ordene e reconheca',
      minAgeBand: KidsAgeBand.preschool,
      caption: 'Coloque na ordem certa!',
    ),
    KidsGameInfo(
      id: KidsGameId.puzzle,
      title: 'Quebra-cabeca da Tia Cris',
      subtitle: 'Monte uma imagem divertida',
      minAgeBand: KidsAgeBand.preschool,
      caption: 'Monte a figura na ordem!',
    ),
    KidsGameInfo(
      id: KidsGameId.attention,
      title: 'Atencao!',
      subtitle: 'Ache o diferente',
      minAgeBand: KidsAgeBand.preschool,
      caption: 'Qual e o diferente?',
    ),
    KidsGameInfo(
      id: KidsGameId.hygieneFood,
      title: 'Pequeno Doutor',
      subtitle: 'Cuide do ursinho de faz de conta',
      minAgeBand: KidsAgeBand.toddler,
      caption: 'O que vem primeiro: lavar as maos ou comer?',
    ),
  ];

  static KidsGameInfo byId(KidsGameId id) =>
      all.firstWhere((KidsGameInfo g) => g.id == id);

  static List<KidsGameInfo> forBand(KidsAgeBand band) {
    final int rank = band.index;
    return all.where((KidsGameInfo g) => g.minAgeBand.index <= rank).toList();
  }
}

class KidsAvatar {
  const KidsAvatar({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;

  static const List<KidsAvatar> options = <KidsAvatar>[
    KidsAvatar(id: 'capi', label: 'Capi', emoji: '🦫'),
    KidsAvatar(id: 'star', label: 'Estrela', emoji: '⭐'),
    KidsAvatar(id: 'dino', label: 'Dino', emoji: '🦕'),
    KidsAvatar(id: 'rocket', label: 'Foguete', emoji: '🚀'),
    KidsAvatar(id: 'bunny', label: 'Coelho', emoji: '🐰'),
  ];
}
