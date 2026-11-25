import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../domain/kids_logic.dart';
import 'family_chrome.dart';

/// Estado local do Espaço Kids. Não grava voz, prontuário nem Firestore.
class KidsHub extends ChangeNotifier {
  KidsHub._();

  static final KidsHub instance = KidsHub._();

  final KidsControls controls = KidsControls();
  final KidsProgress progress = KidsProgress();
  String childName = 'Enzo Gabriel';
  String ageBand = '3–5 anos';

  void toggle(void Function() change) {
    change();
    notifyListeners();
  }
}

class KidsSpaceScreen extends StatelessWidget {
  const KidsSpaceScreen({this.startOnStories = false, super.key});

  final bool startOnStories;

  @override
  Widget build(BuildContext context) {
    if (startOnStories) {
      return const KidsStoriesScreen();
    }
    return AnimatedBuilder(
      animation: KidsHub.instance,
      builder: (BuildContext context, Widget? _) {
        final KidsHub hub = KidsHub.instance;
        return Scaffold(
          backgroundColor: const Color(0xFFF4ECFF),
          body: Column(
            children: <Widget>[
              const FamilyPortalHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: <Widget>[
                    Text(
                      'Espaço Kids da Tia Cris',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Jogos, histórias e atividades de ${AppConfig.appName}. Assistente virtual, não médica.',
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    CrismedCard(
                      child: Row(
                        children: <Widget>[
                          const TiaCrisAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${hub.childName} · ${hub.ageBand}\n'
                              '${hub.progress.completed.length} atividades concluídas nesta sessão.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Nav(
                          'Histórias',
                          () => _open(context, const KidsStoriesScreen()),
                        ),
                        _Nav(
                          'Colorir',
                          () => _open(context, const KidsColorScreen()),
                        ),
                        _Nav(
                          'Conversar',
                          () => _open(context, const KidsAssistantScreen()),
                        ),
                        _Nav(
                          'Responsáveis',
                          () => _open(context, const KidsParentScreen()),
                        ),
                        _Nav(
                          'Recepção',
                          () => _open(context, const KidsReceptionScreen()),
                        ),
                        _Nav(
                          'Painel Kids',
                          () => _open(context, const KidsAdminScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jogos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.92,
                      children: <Widget>[
                        for (final KidsGameInfo game in KidsCatalog.games)
                          if (hub.controls.allows(game.id))
                            _GameTile(
                              game: game,
                              done: hub.progress.completed.contains(game.id),
                              onPlay: () => _open(
                                context,
                                KidsPlayScreen(gameId: game.id),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              const FamilyBottomBar(current: 'Espaço Kids'),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class TiaCrisAvatar extends StatelessWidget {
  const TiaCrisAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 28,
      backgroundColor: Color(0xFFF3E9FF),
      child: Icon(Icons.face_3_rounded, color: AppColors.brand, size: 32),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.onPlay,
    required this.done,
  });

  final KidsGameInfo game;
  final VoidCallback onPlay;
  final bool done;

  @override
  Widget build(BuildContext context) {
    const List<Color> colors = <Color>[
      Color(0xFFD7E4FF),
      Color(0xFFE7D4FF),
      Color(0xFFFFE0C2),
      Color(0xFFFFF3C4),
      Color(0xFFFFD6E8),
      Color(0xFFD9F7E8),
      Color(0xFFFFD0D0),
      Color(0xFFD6F0FF),
      Color(0xFFE4F7C8),
      Color(0xFFE6E0FF),
    ];
    final int index = KidsCatalog.games.indexWhere(
      (KidsGameInfo g) => g.id == game.id,
    );
    final Color color = colors[index.clamp(0, colors.length - 1)];
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              game.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              game.subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(done ? 'De novo' : 'Jogar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KidsGameCard extends StatelessWidget {
  const KidsGameCard({
    required this.game,
    required this.onPlay,
    required this.done,
    super.key,
  });

  final KidsGameInfo game;
  final VoidCallback onPlay;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      child: Row(
        children: <Widget>[
          const Icon(Icons.toys_rounded, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  game.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  game.subtitle,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                if (game.id == 'vaccine')
                  const Text(
                    'Conteúdo para revisão profissional',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onPlay,
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            child: Text(done ? 'De novo' : 'Jogar'),
          ),
        ],
      ),
    );
  }
}

class KidsPlayScreen extends StatefulWidget {
  const KidsPlayScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<KidsPlayScreen> createState() => _KidsPlayScreenState();
}

class _KidsPlayScreenState extends State<KidsPlayScreen> {
  late final Object _game = _create(widget.gameId);
  bool _finished = false;

  Object _create(String id) => switch (id) {
    'doctor' => DoctorGame(),
    'brush' => BrushGame(),
    'food' => PlateGame(),
    'memory' => MemoryGame(),
    'puzzle' => PuzzleGame(),
    'hands' => StepGame(const <String>[
      'torneira',
      'sabonete',
      'esfregar',
      'enxaguar',
      'secar',
    ]),
    'feelings' => FeelingGame(),
    'vaccine' => StepGame(const <String>[
      'chegar',
      'explicar',
      'respirar',
      'abraço',
    ]),
    'shapes' => ShapeGame(),
    'sleep' => StepGame(const <String>[
      'escovar',
      'pijama',
      'guardar',
      'história',
    ]),
    _ => DoctorGame(),
  };

  void _refresh() {
    final bool done = switch (_game) {
      DoctorGame g => g.done,
      BrushGame g => g.done,
      PlateGame g => g.done,
      MemoryGame g => g.done,
      PuzzleGame g => g.done,
      StepGame g => g.done,
      FeelingGame g => g.done,
      ShapeGame g => g.done,
      _ => false,
    };
    if (done && !_finished) {
      _finished = true;
      KidsHub.instance.progress.complete(
        widget.gameId,
        persist: !KidsHub.instance.controls.reception,
      );
      KidsHub.instance.toggle(() {});
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final KidsGameInfo info = KidsCatalog.games.firstWhere(
      (KidsGameInfo g) => g.id == widget.gameId,
      orElse: () => KidsCatalog.games.first,
    );
    return Scaffold(
      appBar: AppBar(title: Text(info.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              info.subtitle,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            Expanded(child: _board()),
            if (_finished)
              const Text(
                'Conquista desta brincadeira. Sem pressa e sem ranking.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _board() {
    return switch (_game) {
      DoctorGame g => _Doctor(game: g, onChanged: _refresh),
      BrushGame g => _Brush(game: g, onChanged: _refresh),
      PlateGame g => _Plate(game: g, onChanged: _refresh),
      MemoryGame g => _Memory(game: g, onChanged: _refresh),
      PuzzleGame g => _Puzzle(game: g, onChanged: _refresh),
      StepGame g => _Steps(game: g, onChanged: _refresh),
      FeelingGame g => _Feelings(game: g, onChanged: _refresh),
      ShapeGame g => _Shapes(game: g, onChanged: _refresh),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Doctor extends StatelessWidget {
  const _Doctor({required this.game, required this.onChanged});

  final DoctorGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final String tool in DoctorGame.tools)
          FilledButton(
            onPressed: () {
              game.use(tool);
              onChanged();
            },
            child: Text(game.used.contains(tool) ? '$tool ok' : tool),
          ),
      ],
    );
  }
}

class _Brush extends StatelessWidget {
  const _Brush({required this.game, required this.onChanged});

  final BrushGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (int i = 0; i < game.clean.length; i++)
          IconButton(
            tooltip: 'Dente ${i + 1}',
            onPressed: () {
              game.brush(i);
              onChanged();
            },
            icon: Icon(
              Icons.sentiment_satisfied_alt_rounded,
              color: game.clean[i] ? AppColors.success : AppColors.honey,
              size: 40,
            ),
          ),
      ],
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.game, required this.onChanged});

  final PlateGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final String food in PlateGame.foods)
          FilterChip(
            label: Text(food),
            selected: game.plate.contains(food),
            onSelected: (_) {
              game.add(food);
              onChanged();
            },
          ),
      ],
    );
  }
}

class _Memory extends StatelessWidget {
  const _Memory({required this.game, required this.onChanged});

  final MemoryGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      children: <Widget>[
        for (int i = 0; i < game.deck.length; i++)
          Padding(
            padding: const EdgeInsets.all(4),
            child: FilledButton(
              onPressed: () {
                game.tap(i);
                onChanged();
              },
              child: Text(game.open[i] || game.matched[i] ? game.deck[i] : '?'),
            ),
          ),
      ],
    );
  }
}

class _Puzzle extends StatelessWidget {
  const _Puzzle({required this.game, required this.onChanged});

  final PuzzleGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Toque a peça e o lugar com o mesmo número.'),
        for (int i = 0; i < game.size; i++)
          ListTile(
            title: Text('Peça $i'),
            trailing: Text(game.placed[i] == null ? 'encaixar' : 'ok'),
            onTap: () {
              game.place(i, i);
              onChanged();
            },
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.game, required this.onChanged});

  final StepGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Passo ${game.index + 1} de ${game.steps.length}'),
        for (final String step in game.steps)
          ListTile(
            title: Text(step),
            onTap: () {
              game.advance(step);
              onChanged();
            },
          ),
      ],
    );
  }
}

class _Feelings extends StatelessWidget {
  const _Feelings({required this.game, required this.onChanged});

  final FeelingGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Escolha um sentimento. Isto não é diagnóstico.'),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final String feeling in FeelingGame.options)
              ChoiceChip(
                label: Text(feeling),
                selected: game.selected == feeling,
                onSelected: (_) {
                  game.choose(feeling);
                  onChanged();
                },
              ),
          ],
        ),
        TextButton(
          onPressed: () {
            game.breathe();
            onChanged();
          },
          child: Text('Respirar (${game.breaths}/3)'),
        ),
      ],
    );
  }
}

class _Shapes extends StatelessWidget {
  const _Shapes({required this.game, required this.onChanged});

  final ShapeGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final String shape in game.answer.keys)
          ListTile(
            title: Text('$shape → ${game.answer[shape]}'),
            trailing: Text(game.placed.containsKey(shape) ? 'ok' : 'soltar'),
            onTap: () {
              game.drop(shape, game.answer[shape]!);
              onChanged();
            },
          ),
      ],
    );
  }
}

class KidsStoriesScreen extends StatefulWidget {
  const KidsStoriesScreen({super.key});

  @override
  State<KidsStoriesScreen> createState() => _KidsStoriesScreenState();
}

class _KidsStoriesScreenState extends State<KidsStoriesScreen> {
  KidsStory? _story;
  int _page = 0;
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final KidsStory? story = _story;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórias da Tia Cris')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: story == null
            ? ListView(
                children: <Widget>[
                  for (final KidsStory item in KidsCatalog.stories)
                    ListTile(
                      title: Text(item.title),
                      subtitle: const Text(
                        'Narração em texto. Áudio gravado ainda não está no app.',
                      ),
                      onTap: () => setState(() {
                        _story = item;
                        _page = 0;
                      }),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    story.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(story.pages[_page]),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: _page == 0
                            ? null
                            : () => setState(() => _page -= 1),
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _playing = !_playing),
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      IconButton(
                        onPressed: _page == story.pages.length - 1
                            ? null
                            : () => setState(() => _page += 1),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      Text(_playing ? 'lendo' : 'pausado'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class KidsColorScreen extends StatefulWidget {
  const KidsColorScreen({super.key});

  @override
  State<KidsColorScreen> createState() => _KidsColorScreenState();
}

class _KidsColorScreenState extends State<KidsColorScreen> {
  final List<Color> _strokes = <Color>[];
  Color _color = AppColors.brand;
  bool _erase = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colorir'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Desfazer',
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(_strokes.removeLast),
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Limpar',
            onPressed: () => setState(_strokes.clear),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onPanUpdate: (_) =>
                  setState(() => _strokes.add(_erase ? Colors.white : _color)),
              child: CustomPaint(
                painter: _ColorPainter(_strokes),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Wrap(
            children: <Widget>[
              for (final Color c in <Color>[
                AppColors.brand,
                AppColors.raspberry,
                AppColors.success,
                AppColors.honey,
              ])
                IconButton(
                  onPressed: () => setState(() {
                    _color = c;
                    _erase = false;
                  }),
                  icon: Icon(Icons.circle, color: c),
                ),
              IconButton(
                onPressed: () => setState(() => _erase = true),
                icon: const Icon(Icons.auto_fix_off_rounded),
              ),
              TextButton(
                onPressed: () {
                  KidsHub.instance.progress.complete(
                    'colorir',
                    persist: !KidsHub.instance.controls.reception,
                  );
                  crismedToast(
                    context,
                    'Desenho guardado só neste aparelho, nesta sessão.',
                  );
                },
                child: const Text('Salvar local'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPainter extends CustomPainter {
  _ColorPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      final double x = 20 + (i % 24) * 18;
      final double y = 40 + (i ~/ 24) * 18;
      canvas.drawCircle(Offset(x, y), 8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColorPainter oldDelegate) =>
      oldDelegate.colors.length != colors.length;
}

class KidsAssistantScreen extends StatefulWidget {
  const KidsAssistantScreen({super.key});

  @override
  State<KidsAssistantScreen> createState() => _KidsAssistantScreenState();
}

class _KidsAssistantScreenState extends State<KidsAssistantScreen> {
  String _state = 'pronta';
  String _line =
      'Oi, eu sou a Tia Cris, uma assistente virtual. Não sou médica e não dou remédio.';
  bool _childVoice = false;

  void _say(String text) {
    if (!KidsHub.instance.controls.aiAllowed) {
      setState(() {
        _state = 'bloqueada';
        _line = 'A família ainda não autorizou a conversa com a Tia Cris Kids.';
      });
      return;
    }
    setState(() {
      _state = 'falando';
      _line = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tia Cris Kids')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Estado: $_state · voz ${_childVoice ? 'infantil' : 'adulta acolhedora'}',
            ),
            const SizedBox(height: 12),
            Text(_line),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: () => _say(
                    'Vamos brincar com calma. Escolha um jogo quando quiser.',
                  ),
                  child: const Text('Ouvir'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _state = 'interrompida'),
                  child: const Text('Interromper'),
                ),
                FilterChip(
                  label: const Text('Voz infantil'),
                  selected: _childVoice,
                  onSelected: (bool v) => setState(() => _childVoice = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Sem microfone por padrão, sem gravar voz e sem prontuário. As falas são textos prontos, sem API.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class KidsParentScreen extends StatelessWidget {
  const KidsParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: KidsHub.instance,
      builder: (BuildContext context, Widget? _) {
        final KidsControls c = KidsHub.instance.controls;
        return Scaffold(
          appBar: AppBar(title: const Text('Responsáveis')),
          body: ListView(
            children: <Widget>[
              SwitchListTile(
                title: const Text('Estímulos reduzidos'),
                value: c.reducedStimuli,
                onChanged: (bool v) =>
                    KidsHub.instance.toggle(() => c.reducedStimuli = v),
              ),
              SwitchListTile(
                title: const Text('Som'),
                value: c.sound,
                onChanged: (bool v) =>
                    KidsHub.instance.toggle(() => c.sound = v),
              ),
              SwitchListTile(
                title: const Text('Autorizar Tia Cris Kids'),
                subtitle: const Text('Sem isto, a assistente não conversa.'),
                value: c.aiAllowed,
                onChanged: (bool v) =>
                    KidsHub.instance.toggle(() => c.aiAllowed = v),
              ),
              SwitchListTile(
                title: const Text('Autorizar microfone'),
                subtitle: const Text(
                  'Nesta versão o microfone não grava mesmo autorizado.',
                ),
                value: c.micAllowed,
                onChanged: (bool v) =>
                    KidsHub.instance.toggle(() => c.micAllowed = v),
              ),
              ListTile(
                title: Text('Tempo máximo: ${c.maxMinutes} min'),
                trailing: IconButton(
                  onPressed: () =>
                      KidsHub.instance.toggle(() => c.maxMinutes += 5),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              ListTile(
                title: const Text('Apagar histórico desta sessão'),
                onTap: () => KidsHub.instance.toggle(
                  KidsHub.instance.progress.completed.clear,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sem anúncios, compras ou ranking. As preferências ficam só na memória deste aparelho até haver coleção própria com regras.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class KidsReceptionScreen extends StatelessWidget {
  const KidsReceptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool on = KidsHub.instance.controls.reception;
    return Scaffold(
      appBar: AppBar(title: const Text('Modo recepção')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Sessão de visitante para tablet da sala de espera. Sem prontuário, sem financeiro e sem nome de outra criança.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                KidsHub.instance.toggle(() {
                  KidsHub.instance.controls.reception = !on;
                  if (on) KidsHub.instance.progress.clearSession();
                });
              },
              child: Text(
                on ? 'Encerrar e limpar' : 'Começar sessão temporária',
              ),
            ),
            if (on)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const KidsPlayScreen(gameId: 'memory'),
                  ),
                ),
                child: const Text('Jogar memória sem guardar'),
              ),
          ],
        ),
      ),
    );
  }
}

class KidsAdminScreen extends StatelessWidget {
  const KidsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: KidsHub.instance,
      builder: (BuildContext context, Widget? _) {
        final KidsControls c = KidsHub.instance.controls;
        return Scaffold(
          appBar: AppBar(title: const Text('Painel Kids')),
          body: ListView(
            children: <Widget>[
              const ListTile(
                title: Text('Histórias e desenhos'),
                subtitle: Text(
                  'Catálogo local, marcado para revisão antes de publicar.',
                ),
              ),
              for (final KidsGameInfo game in KidsCatalog.games)
                SwitchListTile(
                  title: Text(game.title),
                  value: c.allowed.contains(game.id),
                  onChanged: (bool v) => KidsHub.instance.toggle(() {
                    if (v) {
                      c.allowed.add(game.id);
                    } else {
                      c.allowed.remove(game.id);
                    }
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _KidsBar extends StatelessWidget {
  const _KidsBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const <Widget>[
            _BarItem(Icons.home_rounded, 'Início'),
            _BarItem(Icons.toys_rounded, 'Kids'),
            _BarItem(Icons.family_restroom_rounded, 'Família'),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: AppColors.brand),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
