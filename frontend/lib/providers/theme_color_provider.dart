import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opsi warna tema aplikasi.
class ThemeColorOption {
  const ThemeColorOption(this.name, this.seed);

  final String name;
  final Color seed;
}

/// 3 pilihan warna tema yang tersedia di Pengaturan.
const List<ThemeColorOption> themeColorOptions = [
  ThemeColorOption('Oranye', Color(0xFFFFA726)), // default (tema telur)
  ThemeColorOption('Hijau', Color(0xFF66BB6A)),
  ThemeColorOption('Biru', Color(0xFF42A5F5)),
];

class ThemeColorState {
  const ThemeColorState({this.index = 0, this.loaded = false});

  /// Index warna terpilih di [themeColorOptions].
  final int index;

  /// true setelah nilai dibaca dari SharedPreferences.
  final bool loaded;

  ThemeColorState copyWith({int? index, bool? loaded}) => ThemeColorState(
        index: index ?? this.index,
        loaded: loaded ?? this.loaded,
      );
}

class ThemeColorNotifier extends Notifier<ThemeColorState> {
  static const _prefsKey = 'theme_color_index';

  @override
  ThemeColorState build() {
    Future.microtask(_load);
    return const ThemeColorState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefsKey) ?? 0;
    state = ThemeColorState(
      index: index.clamp(0, themeColorOptions.length - 1),
      loaded: true,
    );
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= themeColorOptions.length) return;
    state = ThemeColorState(index: index, loaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, index);
  }
}

final themeColorProvider =
    NotifierProvider<ThemeColorNotifier, ThemeColorState>(
        ThemeColorNotifier.new);
