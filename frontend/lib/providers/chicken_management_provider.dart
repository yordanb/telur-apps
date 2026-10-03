import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chicken_management.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class ChickenManagementState {
  final List<ChickenManagement> managements;
  final bool isLoading;
  final String? error;

  const ChickenManagementState({
    this.managements = const [],
    this.isLoading = false,
    this.error,
  });

  ChickenManagementState copyWith({
    List<ChickenManagement>? managements,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChickenManagementState(
      managements: managements ?? this.managements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class ChickenManagementNotifier extends Notifier<ChickenManagementState> {
  static const _endpoint = '/chicken-managements/';
  static const _queueKey = LocalStorageService.chickenManagementQueueKey;
  static const _cacheKey = LocalStorageService.chickenManagementCacheKey;

  @override
  ChickenManagementState build() {
    Future.microtask(() => fetchManagements());
    return const ChickenManagementState();
  }

  Future<void> fetchManagements() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => ChickenManagement.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = ChickenManagementState(managements: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = ChickenManagementState(
        error: e.toString(),
        managements: [
          ...parseList(queued, ChickenManagement.fromJson),
          ...parseList(cached, ChickenManagement.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(ChickenManagement m) => {
        'id': m.id,
        'user_id': m.userId,
        'date': m.date.toIso8601String(),
        'total_chickens': m.totalChickens,
        'healthy_chickens': m.healthyChickens,
        'sick_chickens': m.sickChickens,
        'dead_chickens': m.deadChickens,
        'new_chickens': m.newChickens,
        'notes': m.notes,
        'created_at': m.createdAt.toIso8601String(),
        'updated_at': m.updatedAt?.toIso8601String(),
      };

  Future<SaveResult> createManagement(ChickenManagement management) async {
    try {
      final response = await ApiService.post(
          _endpoint, management.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newManagement =
            ChickenManagement.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          managements: [newManagement, ...state.managements],
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      final queued = {
        ...management.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': management.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        managements: [
          ChickenManagement.fromJson(queued),
          ...state.managements
        ],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateManagement(
      int id, ChickenManagement management) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, management);
    }
    try {
      final response = await ApiService.put(
          '$_endpoint$id', management.toJson());
      if (response.statusCode == 200) {
        final updated =
            ChickenManagement.fromJson(jsonDecode(response.body));
        final list = List<ChickenManagement>.from(state.managements);
        final index = list.indexWhere((m) => m.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(managements: list);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Edit entri yang masih di antrean: ubah antrean + state lokal.
  Future<bool> _updateQueued(
      int id, ChickenManagement management) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...management.toJson(),
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<ChickenManagement>.from(state.managements);
    final stateIndex = list.indexWhere((m) => m.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = ChickenManagement.fromJson(queue[index]);
    }
    state = state.copyWith(managements: list);
    return true;
  }

  Future<bool> deleteManagement(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        managements: state.managements.where((m) => m.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          managements:
              state.managements.where((m) => m.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final chickenManagementProvider =
    NotifierProvider<ChickenManagementNotifier, ChickenManagementState>(
        ChickenManagementNotifier.new);
