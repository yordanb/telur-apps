import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

/// Hasil operasi simpan: langsung ke server, ditahan di antrean offline,
/// atau gagal total.
enum SaveResult { synced, queued, failed }

/// Ringkasan satu putaran sinkronisasi.
class SyncReport {
  final int synced;
  final int pending;

  const SyncReport({required this.synced, required this.pending});
}

/// Parse defensif: entri antrean lama/rusak dilewati, bukan crash.
List<T> parseList<T>(
    List<Map<String, dynamic>> raw, T Function(Map<String, dynamic>) fromJson) {
  final out = <T>[];
  for (final json in raw) {
    try {
      out.add(fromJson(json));
    } catch (_) {
      // lewati entri rusak
    }
  }
  return out;
}

class _QueueConfig {
  final String queueKey;
  final String endpoint;
  final Set<String> createKeys;

  const _QueueConfig(this.queueKey, this.endpoint, this.createKeys);
}

const _queues = [
  _QueueConfig(
    LocalStorageService.eggProductionQueueKey,
    '/egg-productions/',
    {
      'date',
      'total_eggs',
      'good_eggs',
      'bad_eggs',
      'weight_avg',
      'notes',
    },
  ),
  _QueueConfig(
    LocalStorageService.chickenManagementQueueKey,
    '/chicken-managements/',
    {
      'date',
      'total_chickens',
      'healthy_chickens',
      'sick_chickens',
      'dead_chickens',
      'new_chickens',
      'notes',
    },
  ),
  _QueueConfig(
    LocalStorageService.feedRecordQueueKey,
    '/feed-records/',
    {
      'date',
      'feed_type',
      'quantity_kg',
      'cost_per_kg',
      'total_cost',
      'notes',
    },
  ),
  _QueueConfig(
    LocalStorageService.costRecordQueueKey,
    '/cost-records/',
    {'date', 'category', 'description', 'amount', 'notes'},
  ),
  _QueueConfig(
    LocalStorageService.eggSaleQueueKey,
    '/egg-sales/',
    {'date', 'unit', 'quantity', 'price_per_unit', 'notes'},
  ),
  _QueueConfig(
    LocalStorageService.cashTransactionQueueKey,
    '/cash-transactions/',
    {'date', 'direction', 'category', 'description', 'amount', 'notes'},
  ),
];

class SyncService {
  /// ID sementara untuk entri antrean (negatif → mudah dikenali di UI).
  static int tempId() => -DateTime.now().millisecondsSinceEpoch;

  static bool isTempId(int id) => id < 0;

  /// Jumlah seluruh entri yang masih menunggu dikirim.
  static Future<int> pendingCount() async {
    var total = 0;
    for (final q in _queues) {
      total += (await LocalStorageService.readList(q.queueKey)).length;
    }
    return total;
  }

  /// Kirim semua antrean ke server. Tidak pernah throw: kegagalan jaringan
  /// atau respons non-2xx membuat entri tetap di antrean (kecuali 401 —
  /// token tidak valid — seluruh proses dihentikan agar tidak spam server).
  static Future<SyncReport> syncAll() async {
    var synced = 0;
    try {
      for (final q in _queues) {
        final items = await LocalStorageService.readList(q.queueKey);
        if (items.isEmpty) continue;

        final remaining = <Map<String, dynamic>>[];
        for (final item in items) {
          final body = <String, dynamic>{};
          for (final key in q.createKeys) {
            if (item.containsKey(key)) body[key] = item[key];
          }
          try {
            final response = await ApiService.post(q.endpoint, body);
            if (response.statusCode == 200 ||
                response.statusCode == 201) {
              synced++;
            } else if (response.statusCode == 401) {
              // Token bermasalah: hentikan, antrean dibiarkan utuh.
              remaining.add(item);
              final rest = items.sublist(items.indexOf(item) + 1);
              remaining.addAll(rest);
              await LocalStorageService.writeList(q.queueKey, remaining);
              return SyncReport(
                  synced: synced, pending: await pendingCount());
            } else {
              remaining.add(item);
            }
          } catch (_) {
            // Jaringan gagal: sisakan + hentikan antrean ini.
            remaining.add(item);
            remaining.addAll(items.sublist(items.indexOf(item) + 1));
            break;
          }
        }
        await LocalStorageService.writeList(q.queueKey, remaining);
      }
    } catch (_) {
      // sync tidak boleh merusak alur utama
    }
    return SyncReport(synced: synced, pending: await pendingCount());
  }
}

/// Jumlah antrean untuk badge/banner UI. Invalidate setelah operasi antrean.
final pendingCountProvider = FutureProvider<int>((ref) async {
  return SyncService.pendingCount();
});
