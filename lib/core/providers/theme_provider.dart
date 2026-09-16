import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema do usuario, persistida entre sessoes.
///
/// O padrao e `system`: respeita o modo escuro do aparelho — importante para
/// quem abre o app de madrugada com um bebe no colo.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';

  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _restore();
    // Identidade oficial das referências é light.
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    _prefs = await SharedPreferences.getInstance();
    final String? saved = _prefs?.getString(_key);
    if (saved == null) {
      state = ThemeMode.light;
      return;
    }
    state = ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == saved,
      orElse: () => ThemeMode.light,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_key, mode.name);
  }

  /// Alterna claro <-> escuro (ignora `system`).
  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
