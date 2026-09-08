import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/storage_keys.dart';
import '../storage/storage_manager.dart';

/// Holds the active [ThemeMode] and persists the user's choice. Defaults to
/// following the system so every screen honors light/dark automatically.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._storage) : super(_read(_storage));

  final StorageManager _storage;

  static ThemeMode _read(StorageManager storage) {
    return switch (storage.getString(StorageKeys.themeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    emit(mode);
    await _storage.setString(StorageKeys.themeMode, mode.name);
  }

  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
