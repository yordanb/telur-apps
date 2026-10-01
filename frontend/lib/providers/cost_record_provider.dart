import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/cost_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class CostRecordProvider with ChangeNotifier {
  List<CostRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<CostRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/cost-records/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _records = data.map((json) => CostRecord.fromJson(json)).toList();
      }
    } catch (e) {
      _error = e.toString();
      final offlineData = await LocalStorageService.getOfflineCostRecords();
      _records = offlineData.map((json) => CostRecord.fromJson(json)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createRecord(CostRecord record) async {
    try {
      final response = await ApiService.post('/cost-records/', record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newRecord = CostRecord.fromJson(jsonDecode(response.body));
        _records.insert(0, newRecord);
        notifyListeners();
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
      final response = await ApiService.put('/cost-records/$id', record.toJson());
      if (response.statusCode == 200) {
        final updatedRecord = CostRecord.fromJson(jsonDecode(response.body));
        final index = _records.indexWhere((r) => r.id == id);
        if (index != -1) {
          _records[index] = updatedRecord;
          notifyListeners();
        }
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
        _records.removeWhere((r) => r.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
