import 'package:flutter/foundation.dart';
import '../models/egg_production.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class EggProductionProvider with ChangeNotifier {
  List<EggProduction> _productions = [];
  bool _isLoading = false;
  String? _error;

  List<EggProduction> get productions => _productions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProductions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/egg-productions/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _productions = data.map((json) => EggProduction.fromJson(json)).toList();
      }
    } catch (e) {
      _error = e.toString();
      // Load from local storage if offline
      final offlineData = await LocalStorageService.getOfflineEggProductions();
      _productions = offlineData.map((json) => EggProduction.fromJson(json)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduction(EggProduction production) async {
    try {
      final response = await ApiService.post('/egg-productions/', production.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newProduction = EggProduction.fromJson(jsonDecode(response.body));
        _productions.insert(0, newProduction);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // Save to local storage if offline
      await LocalStorageService.saveOfflineEggProduction(production.toJson());
      return false;
    }
  }

  Future<bool> updateProduction(int id, EggProduction production) async {
    try {
      final response = await ApiService.put('/egg-productions/$id', production.toJson());
      if (response.statusCode == 200) {
        final updatedProduction = EggProduction.fromJson(jsonDecode(response.body));
        final index = _productions.indexWhere((p) => p.id == id);
        if (index != -1) {
          _productions[index] = updatedProduction;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProduction(int id) async {
    try {
      final response = await ApiService.delete('/egg-productions/$id');
      if (response.statusCode == 200) {
        _productions.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
