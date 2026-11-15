import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio do Kids: mute/volume reais + feedback de sistema.
/// Pacote de voz infantil (TTS/assets) fica pendente de arquivos oficiais —
/// as legendas sincronizam com cada atividade via [lastCaption].
class KidsAudioController extends StateNotifier<KidsAudioState> {
  KidsAudioController() : super(const KidsAudioState());

  void setMuted(bool muted) => state = state.copyWith(muted: muted);

  void setVolume(double volume) =>
      state = state.copyWith(volume: volume.clamp(0, 1));

  Future<void> playCue(String caption) async {
    state = state.copyWith(lastCaption: caption);
    if (state.muted || state.volume <= 0) {
      return;
    }
    await SystemSound.play(SystemSoundType.click);
  }
}

class KidsAudioState {
  const KidsAudioState({
    this.muted = false,
    this.volume = 0.8,
    this.lastCaption = '',
  });

  final bool muted;
  final double volume;
  final String lastCaption;

  KidsAudioState copyWith({
    bool? muted,
    double? volume,
    String? lastCaption,
  }) =>
      KidsAudioState(
        muted: muted ?? this.muted,
        volume: volume ?? this.volume,
        lastCaption: lastCaption ?? this.lastCaption,
      );
}

final StateNotifierProvider<KidsAudioController, KidsAudioState>
    kidsAudioProvider =
    StateNotifierProvider<KidsAudioController, KidsAudioState>(
  (Ref ref) => KidsAudioController(),
);
