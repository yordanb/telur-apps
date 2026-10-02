import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _eggProductionsKey = 'offline_egg_productions';
  static const String _chickenManagementsKey = 'offline_chicken_managements';
  static const String _feedRecordsKey = 'offline_feed_records';
  static const String _costRecordsKey = 'offline_cost_records';
  static const String _eggSalesKey = 'offline_egg_sales';

  // Egg Productions
  static Future<List<Map<String, dynamic>>> getOfflineEggProductions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_eggProductionsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  static Future<void> saveOfflineEggProduction(Map<String, dynamic> production) async {
    final productions = await getOfflineEggProductions();
    productions.add(production);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eggProductionsKey, jsonEncode(productions));
  }

  static Future<void> clearOfflineEggProductions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eggProductionsKey);
  }

  // Chicken Managements
  static Future<List<Map<String, dynamic>>> getOfflineChickenManagements() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_chickenManagementsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  static Future<void> saveOfflineChickenManagement(Map<String, dynamic> management) async {
    final managements = await getOfflineChickenManagements();
    managements.add(management);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chickenManagementsKey, jsonEncode(managements));
  }

  static Future<void> clearOfflineChickenManagements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chickenManagementsKey);
  }

  // Feed Records
  static Future<List<Map<String, dynamic>>> getOfflineFeedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_feedRecordsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  static Future<void> saveOfflineFeedRecord(Map<String, dynamic> record) async {
    final records = await getOfflineFeedRecords();
    records.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedRecordsKey, jsonEncode(records));
  }

  static Future<void> clearOfflineFeedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedRecordsKey);
  }

  // Cost Records
  static Future<List<Map<String, dynamic>>> getOfflineCostRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_costRecordsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  static Future<void> saveOfflineCostRecord(Map<String, dynamic> record) async {
    final records = await getOfflineCostRecords();
    records.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_costRecordsKey, jsonEncode(records));
  }

  static Future<void> clearOfflineCostRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_costRecordsKey);
  }

  // Egg Sales
  static Future<List<Map<String, dynamic>>> getOfflineEggSales() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_eggSalesKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  static Future<void> saveOfflineEggSale(Map<String, dynamic> sale) async {
    final sales = await getOfflineEggSales();
    sales.add(sale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eggSalesKey, jsonEncode(sales));
  }

  static Future<void> clearOfflineEggSales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eggSalesKey);
  }
}
