import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/egg_sale.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class EggSaleState {
  final List<EggSale> sales;
  final bool isLoading;
  final String? error;

  const EggSaleState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
  });

  EggSaleState copyWith({
    List<EggSale>? sales,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EggSaleState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class EggSaleNotifier extends Notifier<EggSaleState> {
  static const _endpoint = '/egg-sales/';
  static const _queueKey = LocalStorageService.eggSaleQueueKey;
  static const _cacheKey = LocalStorageService.eggSaleCacheKey;

  @override
  EggSaleState build() {
    Future.microtask(() => fetchSales());
    return const EggSaleState();
  }

  Future<void> fetchSales() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => EggSale.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = EggSaleState(sales: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = EggSaleState(
        error: e.toString(),
        sales: [
          ...parseList(queued, EggSale.fromJson),
          ...parseList(cached, EggSale.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(EggSale s) => {
        'id': s.id,
        'user_id': s.userId,
        'date': s.date.toIso8601String(),
        'unit': s.unit,
        'quantity': s.quantity,
        'price_per_unit': s.pricePerUnit,
        'total_price': s.totalPrice,
        'notes': s.notes,
        'created_at': s.createdAt.toIso8601String(),
        'updated_at': s.updatedAt?.toIso8601String(),
      };

  Future<SaveResult> createSale(EggSale sale) async {
    try {
      final response = await ApiService.post(_endpoint, sale.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newSale = EggSale.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          sales: [newSale, ...state.sales],
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      // total_price dihitung lokal agar bisa ditampilkan (server hitung ulang).
      final queued = {
        ...sale.toJson(),
        'total_price': sale.quantity * sale.pricePerUnit,
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': sale.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        sales: [EggSale.fromJson(queued), ...state.sales],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateSale(int id, EggSale sale) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, sale);
    }
    try {
      final response = await ApiService.put('$_endpoint$id', sale.toJson());
      if (response.statusCode == 200) {
        final updated = EggSale.fromJson(jsonDecode(response.body));
        final list = List<EggSale>.from(state.sales);
        final index = list.indexWhere((r) => r.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(sales: list);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Edit entri yang masih di antrean: ubah antrean + state lokal.
  Future<bool> _updateQueued(int id, EggSale sale) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...sale.toJson(),
      'total_price': sale.quantity * sale.pricePerUnit,
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<EggSale>.from(state.sales);
    final stateIndex = list.indexWhere((r) => r.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = EggSale.fromJson(queue[index]);
    }
    state = state.copyWith(sales: list);
    return true;
  }

  Future<bool> deleteSale(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        sales: state.sales.where((r) => r.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          sales: state.sales.where((r) => r.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final eggSaleProvider = NotifierProvider<EggSaleNotifier, EggSaleState>(
    EggSaleNotifier.new);
