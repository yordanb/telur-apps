import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/egg_sale.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

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
  @override
  EggSaleState build() {
    Future.microtask(() => fetchSales());
    return const EggSaleState();
  }

  Future<void> fetchSales() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await ApiService.get('/egg-sales/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = EggSaleState(
          sales: data.map((json) => EggSale.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      final offlineData = await LocalStorageService.getOfflineEggSales();
      state = EggSaleState(
        error: e.toString(),
        sales: offlineData.map((json) => EggSale.fromJson(json)).toList(),
      );
    }
  }

  Future<bool> createSale(EggSale sale) async {
    try {
      final response = await ApiService.post('/egg-sales/', sale.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newSale = EggSale.fromJson(jsonDecode(response.body));
        state = state.copyWith(
          sales: [newSale, ...state.sales],
        );
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineEggSale(sale.toJson());
      return false;
    }
  }

  Future<bool> updateSale(int id, EggSale sale) async {
    try {
      final response = await ApiService.put('/egg-sales/$id', sale.toJson());
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

  Future<bool> deleteSale(int id) async {
    try {
      final response = await ApiService.delete('/egg-sales/$id');
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
