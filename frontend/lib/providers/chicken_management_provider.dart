import 'package:flutter/foundation.dart';
import '../models/chicken_management.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class ChickenManagementProvider with ChangeNotifier {
  List<ChickenManagement> _managements = [];
  bool _isLoading = false;
  String? _error;

  List<ChickenManagement> get managements => _managements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchManagements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/chicken-managements/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _managements = data.map((json) => ChickenManagement.fromJson(json)).toList();
      }
    } catch (e) {
      _error = e.toString();
      final offlineData = await LocalStorageService.getOfflineChickenManagements();
      _managements = offlineData.map((json) => ChickenManagement.fromJson(json)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createManagement(ChickenManagement management) async {
    try {
      final response = await ApiService.post('/chicken-managements/', management.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newManagement = ChickenManagement.fromJson(jsonDecode(response.body));
        _managements.insert(0, newManagement);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      await LocalStorageService.saveOfflineChickenManagement(management.toJson());
      return false;
    }
  }

  Future<bool> updateManagement(int id, ChickenManagement management) async {
    try {
      final response = await ApiService.put('/chicken-managements/$id', management.toJson());
      if (response.statusCode == 200) {
        final updatedManagement = ChickenManagement.fromJson(jsonDecode(response.body));
        final index = _managements.indexWhere((m) => m.id == id);
        if (index != -1) {
          _managements[index] = updatedManagement;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteManagement(int id) async {
    try {
      final response = await ApiService.delete('/chicken-managements/$id');
      if (response.statusCode == 200) {
        _managements.removeWhere((m) => m.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
