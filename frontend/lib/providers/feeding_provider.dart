import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feeding.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class FeedingState {
  /// Daftar pemberian + peta stok {jenis: sisa kg} dari server (global).
  final List<Feeding> feedings;
  final Map<String, double> stock;
  final bool isLoading;
  final String? error;

  const FeedingState({
    this.feedings = const [],
    this.stock = const {},
    this.isLoading = false,
    this.error,
  });

  FeedingState copyWith({
    List<Feeding>? feedings,
    Map<String, double>? stock,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FeedingState(
      feedings: feedings ?? this.feedings,
      stock: stock ?? this.stock,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class FeedingNotifier extends Notifier<FeedingState> {
  static const _endpoint = '/feedings/';
  static const _queueKey = LocalStorageService.feedingQueueKey;
  static const _cacheKey = LocalStorageService.feedingCacheKey;

  @override
  FeedingState build() {
    Future.microtask(() => fetchFeedings());
    return const FeedingState();
  }

  Future<void> fetchFeedings() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => Feeding.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        final stock = await _fetchStock();
        state = FeedingState(feedings: items, stock: stock);
        return;
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir (stok terakhir diingat).
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        feedings: [
          ...parseList(queued, Feeding.fromJson),
          ...parseList(cached, Feeding.fromJson),
        ],
      );
    }
  }

  /// Stok global dari server. Gagal → pertahankan stok terakhir.
  Future<Map<String, double>> _fetchStock() async {
    try {
      final response = await ApiService.get('${_endpoint}stock');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    } catch (_) {
      // abaikan, pakai stok terakhir
    }
    return state.stock;
  }

  Future<SaveResult> createFeeding(Feeding feeding) async {
    try {
      final response =
          await ApiService.post(_endpoint, feeding.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newFeeding = Feeding.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          feedings: [newFeeding, ...state.feedings],
          stock: await _fetchStock(),
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      // Validasi stok dihitung ulang saat sinkronisasi.
      final queued = {
        ...feeding.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': feeding.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        feedings: [Feeding.fromJson(queued), ...state.feedings],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateFeeding(int id, Feeding feeding) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, feeding);
    }
    try {
      final response =
          await ApiService.put('$_endpoint$id', feeding.toJson());
      if (response.statusCode == 200) {
        final updated = Feeding.fromJson(jsonDecode(response.body));
        final list = List<Feeding>.from(state.feedings);
        final index = list.indexWhere((r) => r.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(
          feedings: list,
          stock: await _fetchStock(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateQueued(int id, Feeding feeding) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...feeding.toJson(),
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<Feeding>.from(state.feedings);
    final stateIndex = list.indexWhere((r) => r.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = Feeding.fromJson(queue[index]);
    }
    state = state.copyWith(feedings: list);
    return true;
  }

  Future<bool> deleteFeeding(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        feedings: state.feedings.where((r) => r.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          feedings: state.feedings.where((r) => r.id != id).toList(),
          stock: await _fetchStock(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _toCacheJson(Feeding f) => {
        'id': f.id,
        'user_id': f.userId,
        'date': f.date.toIso8601String(),
        'feed_type': f.feedType,
        'quantity_kg': f.quantityKg,
        'notes': f.notes,
        'created_at': f.createdAt.toIso8601String(),
        'updated_at': f.updatedAt?.toIso8601String(),
      };
}

final feedingProvider =
    NotifierProvider<FeedingNotifier, FeedingState>(
        FeedingNotifier.new);
