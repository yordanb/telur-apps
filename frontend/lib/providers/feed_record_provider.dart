import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

// ============== State ==============
class FeedRecordState {
  final List<FeedRecord> records;
  final bool isLoading;
  final String? error;

  const FeedRecordState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  FeedRecordState copyWith({
    List<FeedRecord>? records,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FeedRecordState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============== Notifier ==============
class FeedRecordNotifier extends Notifier<FeedRecordState> {
  @override
  FeedRecordState build() {
    Future.microtask(() => fetchRecords());
    return const FeedRecordState();
  }

  Future<void> fetchRecords() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get('/feed-records/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = FeedRecordState(
          records: data.map((json) => FeedRecord.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      final offlineData =
          await LocalStorageService.getOfflineFeedRecords();
      state = FeedRecordState(
        error: e.toString(),
        records:
            offlineData.map((json) => FeedRecord.fromJson(json)).toList(),
      );
    }
  }

  Future<bool> createRecord(FeedRecord record) async {
    try {
      final response =
          await ApiService.post('/feed-records/', record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newRecord = FeedRecord.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          records: [newRecord, ...state.records],
        );
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineFeedRecord(record.toJson());
      return false;
    }
  }

  Future<bool> updateRecord(int id, FeedRecord record) async {
    try {
      final response =
          await ApiService.put('/feed-records/$id', record.toJson());
      if (response.statusCode == 200) {
        final updated = FeedRecord.fromJson(jsonDecode(response.body));
        final list = List<FeedRecord>.from(state.records);
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
      final response = await ApiService.delete('/feed-records/$id');
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

final feedRecordProvider =
    NotifierProvider<FeedRecordNotifier, FeedRecordState>(
        FeedRecordNotifier.new);
