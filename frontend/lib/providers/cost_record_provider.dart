import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cost_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

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
  @override
  CostRecordState build() {
    Future.microtask(() => fetchRecords());
    return const CostRecordState();
  }

  Future<void> fetchRecords() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get('/cost-records/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = CostRecordState(
          records: data.map((json) => CostRecord.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      final offlineData =
          await LocalStorageService.getOfflineCostRecords();
      state = CostRecordState(
        error: e.toString(),
        records:
            offlineData.map((json) => CostRecord.fromJson(json)).toList(),
      );
    }
  }

  Future<bool> createRecord(CostRecord record) async {
    try {
      final response =
          await ApiService.post('/cost-records/', record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newRecord = CostRecord.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          records: [newRecord, ...state.records],
        );
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineCostRecord(record.toJson());
      return false;
    }
  }

  Future<bool> updateRecord(int id, CostRecord record) async {
    try {
      final response =
          await ApiService.put('/cost-records/$id', record.toJson());
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

  Future<bool> deleteRecord(int id) async {
    try {
      final response = await ApiService.delete('/cost-records/$id');
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
