import 'package:flutter/foundation.dart';
import '../models/feed_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class FeedRecordProvider with ChangeNotifier {
  List<FeedRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<FeedRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/feed-records/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _records = data.map((json) => FeedRecord.fromJson(json)).toList();
      }
    } catch (e) {
      _error = e.toString();
      final offlineData = await LocalStorageService.getOfflineFeedRecords();
      _records = offlineData.map((json) => FeedRecord.fromJson(json)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createRecord(FeedRecord record) async {
    try {
      final response = await ApiService.post('/feed-records/', record.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final newRecord = FeedRecord.fromJson(jsonDecode(response.body));
        _records.insert(0, newRecord);
        notifyListeners();
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
      final response = await ApiService.put('/feed-records/$id', record.toJson());
      if (response.statusCode == 200) {
        final updatedRecord = FeedRecord.fromJson(jsonDecode(response.body));
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
      final response = await ApiService.delete('/feed-records/$id');
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
