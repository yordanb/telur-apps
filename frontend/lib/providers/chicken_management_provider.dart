import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chicken_management.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

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
  @override
  ChickenManagementState build() {
    Future.microtask(() => fetchManagements());
    return const ChickenManagementState();
  }

  Future<void> fetchManagements() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get('/chicken-managements/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = ChickenManagementState(
          managements:
              data.map((json) => ChickenManagement.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      final offlineData =
          await LocalStorageService.getOfflineChickenManagements();
      state = ChickenManagementState(
        error: e.toString(),
        managements: offlineData
            .map((json) => ChickenManagement.fromJson(json))
            .toList(),
      );
    }
  }

  Future<bool> createManagement(ChickenManagement management) async {
    try {
      final response = await ApiService.post(
          '/chicken-managements/', management.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newManagement =
            ChickenManagement.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          managements: [newManagement, ...state.managements],
        );
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineChickenManagement(
          management.toJson());
      return false;
    }
  }

  Future<bool> updateManagement(
      int id, ChickenManagement management) async {
    try {
      final response = await ApiService.put(
          '/chicken-managements/$id', management.toJson());
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

  Future<bool> deleteManagement(int id) async {
    try {
      final response =
          await ApiService.delete('/chicken-managements/$id');
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
