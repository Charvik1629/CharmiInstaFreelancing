import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/storage_manager.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/search_repository.dart';

part 'search_state.dart';

/// Drives the Search screen: debounced people search (GET /users?q=), plus a
/// locally-persisted list of recent queries shown when the box is empty.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository, this._storage) : super(const SearchState()) {
    _loadRecents();
  }

  final SearchRepository _repository;
  final StorageManager _storage;
  Timer? _debounce;

  static const _minChars = 2;
  static const _maxRecents = 8;
  static const _debounceMs = 350;

  void onQueryChanged(String query) {
    final q = query.trim();
    emit(state.copyWith(query: query));
    _debounce?.cancel();
    if (q.length < _minChars) {
      // Too short → drop back to the recents view.
      emit(state.copyWith(status: SearchStatus.idle, results: const []));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () => _run(q));
  }

  /// Runs a recent query immediately (tapped from the recents list).
  Future<void> runRecent(String query) async {
    _debounce?.cancel();
    emit(state.copyWith(query: query));
    await _run(query.trim());
  }

  Future<void> _run(String q) async {
    if (q.length < _minChars) return;
    emit(state.copyWith(status: SearchStatus.searching));
    final result = await _repository.searchUsers(q);
    switch (result) {
      case Success(value: final users):
        _remember(q);
        emit(state.copyWith(
          status: users.isEmpty ? SearchStatus.empty : SearchStatus.results,
          results: users,
          clearError: true,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: SearchStatus.error, errorMessage: f.message));
    }
  }

  void clearQuery() {
    _debounce?.cancel();
    emit(state.copyWith(query: '', status: SearchStatus.idle, results: const []));
  }

  // ---- Recents (local) ----

  void _loadRecents() {
    final raw = _storage.getString(StorageKeys.recentSearches);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).whereType<String>().toList();
      emit(state.copyWith(recents: list));
    } catch (_) {
      /* ignore corrupt cache */
    }
  }

  void _remember(String q) {
    final next = [q, ...state.recents.where((r) => r.toLowerCase() != q.toLowerCase())];
    final capped = next.take(_maxRecents).toList();
    emit(state.copyWith(recents: capped));
    _persistRecents(capped);
  }

  void removeRecent(String q) {
    final next = state.recents.where((r) => r != q).toList();
    emit(state.copyWith(recents: next));
    _persistRecents(next);
  }

  void clearRecents() {
    emit(state.copyWith(recents: const []));
    _persistRecents(const []);
  }

  void _persistRecents(List<String> list) =>
      _storage.setString(StorageKeys.recentSearches, jsonEncode(list));

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
