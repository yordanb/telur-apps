import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/egg_production.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

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
  static const _endpoint = '/egg-productions/';
  static const _queueKey = LocalStorageService.eggProductionQueueKey;
  static const _cacheKey = LocalStorageService.eggProductionCacheKey;

  @override
  EggProductionState build() {
    Future.microtask(() => fetchProductions());
    return const EggProductionState();
  }

  Future<void> fetchProductions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => EggProduction.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = EggProductionState(productions: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = EggProductionState(
        error: e.toString(),
        productions: [
          ...parseList(queued, EggProduction.fromJson),
          ...parseList(cached, EggProduction.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(EggProduction p) => {
        'id': p.id,
        'user_id': p.userId,
        'date': p.date.toIso8601String(),
        'total_eggs': p.totalEggs,
        'good_eggs': p.goodEggs,
        'bad_eggs': p.badEggs,
        'weight_avg': p.weightAvg,
        'notes': p.notes,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt?.toIso8601String(),
        'details': p.details
            .map((d) => {
                  'id': d.id,
                  'chicken_id': d.chickenId,
                  'eggs': d.eggs,
                  'chicken_code': d.chickenCode,
                  'chicken_name': d.chickenName,
                })
            .toList(),
      };

  Future<SaveResult> createProduction(EggProduction production) async {
    try {
      final response =
          await ApiService.post(_endpoint, production.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newProduction =
            EggProduction.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          productions: [newProduction, ...state.productions],
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      final queued = {
        ...production.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': production.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        productions: [
          EggProduction.fromJson(queued),
          ...state.productions
        ],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateProduction(
      int id, EggProduction production) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, production);
    }
    try {
      final response =
          await ApiService.put('$_endpoint$id', production.toJson());
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

  /// Edit entri yang masih di antrean: ubah antrean + state lokal.
  Future<bool> _updateQueued(int id, EggProduction production) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...production.toJson(),
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<EggProduction>.from(state.productions);
    final stateIndex = list.indexWhere((p) => p.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = EggProduction.fromJson(queue[index]);
    }
    state = state.copyWith(productions: list);
    return true;
  }

  Future<bool> deleteProduction(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        productions: state.productions.where((p) => p.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
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
