import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chicken.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class ChickenState {
  final List<Chicken> chickens;
  final bool isLoading;
  final String? error;

  const ChickenState({
    this.chickens = const [],
    this.isLoading = false,
    this.error,
  });

  ChickenState copyWith({
    List<Chicken>? chickens,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChickenState(
      chickens: chickens ?? this.chickens,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class ChickenNotifier extends Notifier<ChickenState> {
  static const _endpoint = '/chickens/';
  static const _queueKey = LocalStorageService.chickenQueueKey;
  static const _cacheKey = LocalStorageService.chickenCacheKey;

  @override
  ChickenState build() {
    Future.microtask(() => fetchChickens());
    return const ChickenState();
  }

  Future<void> fetchChickens() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => Chicken.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = ChickenState(chickens: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = ChickenState(
        error: e.toString(),
        chickens: [
          ...parseList(queued, Chicken.fromJson),
          ...parseList(cached, Chicken.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(Chicken c) => {
        'id': c.id,
        'user_id': c.userId,
        'code': c.code,
        'name': c.name,
        'breed': c.breed,
        'acquired_date': c.acquiredDate?.toIso8601String(),
        'status': c.status,
        'photo_path': c.photoPath,
        'notes': c.notes,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt?.toIso8601String(),
      };

  Future<SaveResult> createChicken(Chicken chicken) async {
    try {
      final response =
          await ApiService.post(_endpoint, chicken.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newChicken = Chicken.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          chickens: [...state.chickens, newChicken]
            ..sort((a, b) => a.code.compareTo(b.code)),
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal (foto ditambahkan saat online).
      final queued = {
        ...chicken.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'photo_path': null,
        'created_at': chicken.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        chickens: [...state.chickens, Chicken.fromJson(queued)]
          ..sort((a, b) => a.code.compareTo(b.code)),
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateChicken(int id, Chicken chicken) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, chicken);
    }
    try {
      final response =
          await ApiService.put('$_endpoint$id', chicken.toJson());
      if (response.statusCode == 200) {
        final updated = Chicken.fromJson(jsonDecode(response.body));
        final list = List<Chicken>.from(state.chickens);
        final index = list.indexWhere((c) => c.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(chickens: list);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateQueued(int id, Chicken chicken) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...chicken.toJson(),
      'id': id,
      'user_id': 0,
      'photo_path': queue[index]['photo_path'],
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<Chicken>.from(state.chickens);
    final stateIndex = list.indexWhere((c) => c.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = Chicken.fromJson(queue[index]);
    }
    state = state.copyWith(chickens: list);
    return true;
  }

  Future<bool> deleteChicken(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        chickens: state.chickens.where((c) => c.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          chickens: state.chickens.where((c) => c.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Upload foto profil. Butuh koneksi online.
  /// Kembalikan photo_path baru jika sukses, null jika gagal.
  Future<String?> uploadPhoto(int id, String filePath) async {
    try {
      final response =
          await ApiService.uploadPhoto('$_endpoint$id/photo', filePath);
      if (response.statusCode == 200) {
        final updated = Chicken.fromJson(jsonDecode(response.body));
        final list = List<Chicken>.from(state.chickens);
        final index = list.indexWhere((c) => c.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(chickens: list);
        // Segarkan cache agar foto tampil saat offline.
        final cached = await LocalStorageService.readList(_cacheKey);
        final cacheIndex =
            cached.indexWhere((item) => item['id'] == id);
        if (cacheIndex != -1) {
          cached[cacheIndex] = _toCacheJson(updated);
          await LocalStorageService.writeList(_cacheKey, cached);
        }
        return updated.photoPath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final chickenProvider =
    NotifierProvider<ChickenNotifier, ChickenState>(
        ChickenNotifier.new);
