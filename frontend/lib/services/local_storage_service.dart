import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal: antrean offline (belum terkirim) + cache terakhir.
///
/// Alur offline-first:
/// - Gagal POST karena jaringan → payload disimpan di antrean (queueKey)
///   dengan id sementara negatif agar bisa ditampilkan & diedit/hapus lokal.
/// - GET sukses → respons server disimpan di cache (cacheKey) agar daftar
///   tetap bisa dilihat saat offline.
/// - [SyncService] mengirim ulang isi antrean saat online kembali.
class LocalStorageService {
  // ============ Kunci antrean (belum terkirim ke server) ============
  static const String eggProductionQueueKey = 'offline_egg_productions';
  static const String chickenManagementQueueKey =
      'offline_chicken_managements';
  static const String feedRecordQueueKey = 'offline_feed_records';
  static const String costRecordQueueKey = 'offline_cost_records';
  static const String eggSaleQueueKey = 'offline_egg_sales';
  static const String cashTransactionQueueKey = 'offline_cash_transactions';
  static const String chickenQueueKey = 'offline_chickens';

  // ============ Kunci cache (respons terakhir dari server) ============
  static const String eggProductionCacheKey = 'cache_egg_productions';
  static const String chickenManagementCacheKey =
      'cache_chicken_managements';
  static const String feedRecordCacheKey = 'cache_feed_records';
  static const String costRecordCacheKey = 'cache_cost_records';
  static const String eggSaleCacheKey = 'cache_egg_sales';
  static const String cashTransactionCacheKey = 'cache_cash_transactions';
  static const String chickenCacheKey = 'cache_chickens';

  static Future<List<Map<String, dynamic>>> readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data != null) {
      try {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<void> writeList(
      String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }
}
