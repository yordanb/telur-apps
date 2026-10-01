import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/egg_production.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

// ============== State ==============
class EggProductionState {
  final List<EggProduction> productions;
  final bool isLoading;
  final String? error;

  const EggProductionState({
    this.productions = const [],
    this.isLoading = false,
    this.error,
  });

  EggProductionState copyWith({
    List<EggProduction>? productions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EggProductionState(
      productions: productions ?? this.productions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class EggProductionNotifier extends Notifier<EggProductionState> {
  @override
  EggProductionState build() {
    Future.microtask(() => fetchProductions());
    return const EggProductionState();
  }

  Future<void> fetchProductions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get('/egg-productions/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = EggProductionState(
          productions:
              data.map((json) => EggProduction.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      final offlineData =
          await LocalStorageService.getOfflineEggProductions();
      state = EggProductionState(
        error: e.toString(),
        productions:
            offlineData.map((json) => EggProduction.fromJson(json)).toList(),
      );
    }
  }

  Future<bool> createProduction(EggProduction production) async {
    try {
      final response =
          await ApiService.post('/egg-productions/', production.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newProduction =
            EggProduction.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          productions: [newProduction, ...state.productions],
        );
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineEggProduction(
          production.toJson());
      return false;
    }
  }

  Future<bool> updateProduction(
      int id, EggProduction production) async {
    try {
      final response =
          await ApiService.put('/egg-productions/$id', production.toJson());
      if (response.statusCode == 200) {
        final updated =
            EggProduction.fromJson(jsonDecode(response.body));
        final productions = List<EggProduction>.from(state.productions);
        final index = productions.indexWhere((p) => p.id == id);
        if (index != -1) productions[index] = updated;
        state = state.copyWith(productions: productions);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProduction(int id) async {
    try {
      final response = await ApiService.delete('/egg-productions/$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          productions:
              state.productions.where((p) => p.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final eggProductionProvider =
    NotifierProvider<EggProductionNotifier, EggProductionState>(
        EggProductionNotifier.new);
