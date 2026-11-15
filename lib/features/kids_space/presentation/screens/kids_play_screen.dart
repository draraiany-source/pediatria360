import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../audio/kids_audio_controller.dart';
import '../../domain/kids_catalog.dart';
import '../../domain/kids_game_logic.dart';
import '../../domain/kids_progress.dart';
import '../providers/kids_providers.dart';

class KidsPlayScreen extends ConsumerStatefulWidget {
  const KidsPlayScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<KidsPlayScreen> createState() => _KidsPlayScreenState();
}

class _KidsPlayScreenState extends ConsumerState<KidsPlayScreen> {
  late final KidsGameId _id;
  MemoryEngine? _memory;
  MatchEngine? _match;
  OrderEngine? _order;
  AttentionEngine? _attention;
  bool _letters = false;
  bool _won = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _id = KidsGameId.values.firstWhere(
      (KidsGameId e) => e.name == widget.gameId,
      orElse: () => KidsGameId.memory,
    );
    _boot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kidsAudioProvider.notifier).playCue(KidsGameInfo.byId(_id).caption);
    });
  }

  void _boot() {
    _won = false;
    _status = '';
    _memory = null;
    _match = null;
    _order = null;
    _attention = null;
    switch (_id) {
      case KidsGameId.memory:
        _memory = KidsGameFactory.memory();
        break;
      case KidsGameId.colorsShapes:
        _match = KidsGameFactory.colorsShapes();
        break;
      case KidsGameId.hygieneFood:
        _match = KidsGameFactory.hygieneFood();
        break;
      case KidsGameId.numbersLetters:
        _order = KidsGameFactory.numbersLetters(letters: _letters);
        break;
      case KidsGameId.puzzle:
        _order = KidsGameFactory.puzzle();
        break;
      case KidsGameId.attention:
        _attention = KidsGameFactory.attention();
        break;
    }
  }

  Future<void> _finish({required int moves}) async {
    if (_won) {
      return;
    }
    setState(() {
      _won = true;
      _status = 'Muito bem!';
    });
    await ref.read(kidsAudioProvider.notifier).playCue('Muito bem!');
    final profile = await ref.read(kidsProgressProvider.future);
    final userProfile = profile;
    if (userProfile == null) {
      return;
    }
    final int stars = KidsGameFactory.starsFor(
      id: _id,
      won: true,
      moves: moves,
    );
    final KidsProgressProfile updated = await ref
        .read(kidsProgressRepositoryProvider)
        .recordWin(profile: userProfile, gameId: _id, stars: stars);
    ref.invalidate(kidsProgressProvider);
    if (mounted) {
      setState(() => _status = 'Ganhou $stars estrela(s)! Total ${updated.totalStars}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final KidsGameInfo info = KidsGameInfo.byId(_id);
    return Scaffold(
      appBar: AppBar(
        title: Text(info.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.kidsPath),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(info.caption, style: const TextStyle(color: AppColors.inkMuted)),
            if (_status.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildBoard()),
            if (_won)
              FilledButton(
                onPressed: () {
                  setState(_boot);
                },
                child: const Text('Jogar de novo'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    switch (_id) {
      case KidsGameId.memory:
        return _memoryBoard();
      case KidsGameId.colorsShapes:
      case KidsGameId.hygieneFood:
        return _matchBoard();
      case KidsGameId.numbersLetters:
        return Column(
          children: <Widget>[
            SwitchListTile(
              title: Text(_letters ? 'Letras' : 'Numeros'),
              value: _letters,
              onChanged: _won
                  ? null
                  : (bool v) {
                      setState(() {
                        _letters = v;
                        _order = KidsGameFactory.numbersLetters(letters: v);
                      });
                    },
            ),
            Expanded(child: _orderBoard()),
          ],
        );
      case KidsGameId.puzzle:
        return _orderBoard();
      case KidsGameId.attention:
        return _attentionBoard();
    }
  }

  Widget _memoryBoard() {
    final MemoryEngine engine = _memory!;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: engine.values.length,
      itemBuilder: (BuildContext context, int i) {
        final bool show = engine.faceUp[i] || engine.matched[i];
        return Material(
          color: show ? AppColors.brandSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _won
                ? null
                : () async {
                    final bool paired = engine.tap(i);
                    setState(() {});
                    if (paired) {
                      await ref
                          .read(kidsAudioProvider.notifier)
                          .playCue('Par encontrado!');
                    }
                    if (engine.completed) {
                      await _finish(moves: engine.moves);
                    } else {
                      setState(() {});
                    }
                  },
            child: Center(
              child: Text(
                show ? '${engine.values[i] + 1}' : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _matchBoard() {
    final MatchEngine engine = _match!;
    if (engine.completed) {
      return const Center(child: Text('Completou!'));
    }
    final String prompt = engine.prompts[engine.index];
    return Column(
      children: <Widget>[
        Text(
          prompt,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final String opt in engine.options)
              FilledButton(
                onPressed: _won
                    ? null
                    : () async {
                        final bool ok = engine.answer(opt);
                        setState(() {});
                        await ref.read(kidsAudioProvider.notifier).playCue(
                              ok ? 'Isso!' : 'Tente outra',
                            );
                        if (engine.completed) {
                          await _finish(moves: engine.correct);
                        }
                      },
                child: Text(opt),
              ),
          ],
        ),
      ],
    );
  }

  Widget _orderBoard() {
    final OrderEngine engine = _order!;
    return Column(
      children: <Widget>[
        Text(
          'Montado: ${engine.built.join(' · ')}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final String v in engine.pool)
              FilledButton.tonal(
                onPressed: _won
                    ? null
                    : () async {
                        final bool ok = engine.pick(v);
                        setState(() {});
                        await ref.read(kidsAudioProvider.notifier).playCue(
                              ok ? 'Boa!' : 'Ordem errada',
                            );
                        if (engine.completed) {
                          await _finish(moves: engine.built.length);
                        }
                      },
                child: Text(v, style: const TextStyle(fontSize: 22)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _attentionBoard() {
    final AttentionEngine engine = _attention!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final String c in engine.choices)
          InkWell(
            onTap: _won
                ? null
                : () async {
                    final bool ok = engine.pick(c);
                    setState(() {});
                    await ref.read(kidsAudioProvider.notifier).playCue(
                          ok ? 'Achou!' : 'Nao e esse',
                        );
                    if (engine.solved) {
                      await _finish(moves: 1);
                    }
                  },
            child: Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                c == 'star' ? '⭐' : '🔵',
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
      ],
    );
  }
}
