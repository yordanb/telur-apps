import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cost_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class CostRecordState {
  final List<CostRecord> records;
  final bool isLoading;
  final String? error;

  const CostRecordState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  CostRecordState copyWith({
    List<CostRecord>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CostRecordState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class CostRecordNotifier extends Notifier<CostRecordState> {
  static const _endpoint = '/cost-records/';
  static const _queueKey = LocalStorageService.costRecordQueueKey;
  static const _cacheKey = LocalStorageService.costRecordCacheKey;

  @override
  CostRecordState build() {
    Future.microtask(() => fetchRecords());
    return const CostRecordState();
  }

  Future<void> fetchRecords() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => CostRecord.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = CostRecordState(records: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = CostRecordState(
        error: e.toString(),
        records: [
          ...parseList(queued, CostRecord.fromJson),
          ...parseList(cached, CostRecord.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(CostRecord r) => {
        'id': r.id,
        'user_id': r.userId,
        'date': r.date.toIso8601String(),
        'category': r.category,
        'subcategory': r.subcategory,
        'description': r.description,
        'amount': r.amount,
        'feed_type': r.feedType,
        'quantity_kg': r.quantityKg,
        'price_per_kg': r.pricePerKg,
        'notes': r.notes,
        'created_at': r.createdAt.toIso8601String(),
        'updated_at': r.updatedAt?.toIso8601String(),
      };

  Future<SaveResult> createRecord(CostRecord record) async {
    try {
      final response =
          await ApiService.post(_endpoint, record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newRecord = CostRecord.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          records: [newRecord, ...state.records],
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      final queued = {
        ...record.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': record.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        records: [CostRecord.fromJson(queued), ...state.records],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateRecord(int id, CostRecord record) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, record);
    }
    try {
      final response =
          await ApiService.put('$_endpoint$id', record.toJson());
      if (response.statusCode == 200) {
        final updated = CostRecord.fromJson(jsonDecode(response.body));
        final list = List<CostRecord>.from(state.records);
        final index = list.indexWhere((r) => r.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(records: list);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Edit entri yang masih di antrean: ubah antrean + state lokal.
  Future<bool> _updateQueued(int id, CostRecord record) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...record.toJson(),
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<CostRecord>.from(state.records);
    final stateIndex = list.indexWhere((r) => r.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = CostRecord.fromJson(queue[index]);
    }
    state = state.copyWith(records: list);
    return true;
  }

  Future<bool> deleteRecord(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        records: state.records.where((r) => r.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          records: state.records.where((r) => r.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final costRecordProvider =
    NotifierProvider<CostRecordNotifier, CostRecordState>(
        CostRecordNotifier.new);
