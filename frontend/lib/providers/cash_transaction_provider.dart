import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cash_transaction.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// ============== State ==============
class CashTransactionState {
  final List<CashTransaction> transactions;
  final bool isLoading;
  final String? error;

  const CashTransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  CashTransactionState copyWith({
    List<CashTransaction>? transactions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CashTransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class CashTransactionNotifier extends Notifier<CashTransactionState> {
  static const _endpoint = '/cash-transactions/';
  static const _queueKey = LocalStorageService.cashTransactionQueueKey;
  static const _cacheKey = LocalStorageService.cashTransactionCacheKey;

  @override
  CashTransactionState build() {
    Future.microtask(() => fetchTransactions());
    return const CashTransactionState();
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get(_endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items =
            data.map((json) => CashTransaction.fromJson(json)).toList();
        await LocalStorageService.writeList(
            _cacheKey, items.map((e) => _toCacheJson(e)).toList());
        state = CashTransactionState(transactions: items);
      }
    } catch (e) {
      // Offline: tampilkan antrean + cache terakhir.
      final cached = await LocalStorageService.readList(_cacheKey);
      final queued = await LocalStorageService.readList(_queueKey);
      state = CashTransactionState(
        error: e.toString(),
        transactions: [
          ...parseList(queued, CashTransaction.fromJson),
          ...parseList(cached, CashTransaction.fromJson),
        ],
      );
    }
  }

  Map<String, dynamic> _toCacheJson(CashTransaction t) => {
        'id': t.id,
        'user_id': t.userId,
        'date': t.date.toIso8601String(),
        'direction': t.direction,
        'category': t.category,
        'description': t.description,
        'amount': t.amount,
        'notes': t.notes,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt?.toIso8601String(),
      };

  Future<SaveResult> createTransaction(CashTransaction tx) async {
    try {
      final response = await ApiService.post(_endpoint, tx.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newTx = CashTransaction.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          transactions: [newTx, ...state.transactions],
        );
        return SaveResult.synced;
      }
      return SaveResult.failed;
    } catch (_) {
      // Jaringan gagal → antrekan lokal dengan id sementara negatif.
      final queued = {
        ...tx.toJson(),
        'id': SyncService.tempId(),
        'user_id': 0,
        'created_at': tx.createdAt.toIso8601String(),
      };
      final queue = await LocalStorageService.readList(_queueKey);
      queue.add(queued);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        transactions: [
          CashTransaction.fromJson(queued),
          ...state.transactions
        ],
      );
      ref.invalidate(pendingCountProvider);
      return SaveResult.queued;
    }
  }

  Future<bool> updateTransaction(int id, CashTransaction tx) async {
    if (SyncService.isTempId(id)) {
      return _updateQueued(id, tx);
    }
    try {
      final response =
          await ApiService.put('$_endpoint$id', tx.toJson());
      if (response.statusCode == 200) {
        final updated = CashTransaction.fromJson(jsonDecode(response.body));
        final list = List<CashTransaction>.from(state.transactions);
        final index = list.indexWhere((r) => r.id == id);
        if (index != -1) list[index] = updated;
        state = state.copyWith(transactions: list);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Edit entri yang masih di antrean: ubah antrean + state lokal.
  Future<bool> _updateQueued(int id, CashTransaction tx) async {
    final queue = await LocalStorageService.readList(_queueKey);
    final index = queue.indexWhere((item) => item['id'] == id);
    if (index == -1) return false;
    queue[index] = {
      ...tx.toJson(),
      'id': id,
      'user_id': 0,
      'created_at': queue[index]['created_at'],
    };
    await LocalStorageService.writeList(_queueKey, queue);
    final list = List<CashTransaction>.from(state.transactions);
    final stateIndex = list.indexWhere((r) => r.id == id);
    if (stateIndex != -1) {
      list[stateIndex] = CashTransaction.fromJson(queue[index]);
    }
    state = state.copyWith(transactions: list);
    return true;
  }

  Future<bool> deleteTransaction(int id) async {
    if (SyncService.isTempId(id)) {
      final queue = await LocalStorageService.readList(_queueKey);
      queue.removeWhere((item) => item['id'] == id);
      await LocalStorageService.writeList(_queueKey, queue);
      state = state.copyWith(
        transactions: state.transactions.where((r) => r.id != id).toList(),
      );
      ref.invalidate(pendingCountProvider);
      return true;
    }
    try {
      final response = await ApiService.delete('$_endpoint$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          transactions:
              state.transactions.where((r) => r.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final cashTransactionProvider =
    NotifierProvider<CashTransactionNotifier, CashTransactionState>(
        CashTransactionNotifier.new);
