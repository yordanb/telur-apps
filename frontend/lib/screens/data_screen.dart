import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chicken_management_provider.dart';
import '../providers/feed_record_provider.dart';
import '../providers/cost_record_provider.dart';
import '../providers/egg_sale_provider.dart';
import '../providers/cash_transaction_provider.dart';
import '../providers/chicken_provider.dart';
import '../services/sync_service.dart';
import 'chicken_management_screen.dart';
import 'feed_record_screen.dart';
import 'cost_record_screen.dart';
import 'egg_sale_screen.dart';
import 'finance_screen.dart';
import 'chicken_screen.dart';
import 'productivity_screen.dart';

/// Tab "Data" — hub berisi 3 catatan sekunder:
/// Ayam, Pakan, dan Biaya. Masing-masing dibuka sebagai layar penuh (push).
class DataScreen extends ConsumerWidget {
  const DataScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await SyncService.syncAll();
    await Future.wait([
      ref.read(chickenManagementProvider.notifier).fetchManagements(),
      ref.read(feedRecordProvider.notifier).fetchRecords(),
      ref.read(costRecordProvider.notifier).fetchRecords(),
      ref.read(eggSaleProvider.notifier).fetchSales(),
      ref.read(cashTransactionProvider.notifier).fetchTransactions(),
      ref.read(chickenProvider.notifier).fetchChickens(),
    ]);
    ref.invalidate(pendingCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chickenCount = ref.watch(
      chickenManagementProvider.select((s) => s.managements.length),
    );
    final feedCount = ref.watch(
      feedRecordProvider.select((s) => s.records.length),
    );
    final costCount = ref.watch(
      costRecordProvider.select((s) => s.records.length),
    );
    final saleCount = ref.watch(
      eggSaleProvider.select((s) => s.sales.length),
    );
    final cashCount = ref.watch(
      cashTransactionProvider.select((s) => s.transactions.length),
    );
    final registryCount = ref.watch(
      chickenProvider.select((s) => s.chickens.length),
    );
    final pending = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            pending.when(
              data: (count) => count > 0
                  ? _PendingBanner(
                      count: count,
                      onSync: () async {
                        await _refresh(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sinkronisasi selesai'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Text(
              'Pilih jenis data yang ingin dikelola',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _DataCard(
              icon: Icons.pets,
              color: Colors.green,
              title: 'Manajemen Ayam',
              subtitle: 'Jumlah ayam, sehat, sakit, mati, dan ayam baru',
              count: chickenCount,
              countLabel: 'entri',
              onTap: () => _open(context, const ChickenManagementScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.grain,
              color: Colors.brown,
              title: 'Pencatatan Pakan',
              subtitle: 'Jenis pakan, jumlah (kg), dan harga per kg',
              count: feedCount,
              countLabel: 'entri',
              onTap: () => _open(context, const FeedRecordScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.attach_money,
              color: Colors.red,
              title: 'Pencatatan Biaya',
              subtitle: 'Biaya pakan, obat, operasional, dan lainnya',
              count: costCount,
              countLabel: 'entri',
              onTap: () => _open(context, const CostRecordScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.shopping_cart,
              color: Colors.teal,
              title: 'Penjualan Telur',
              subtitle: 'Penjualan per butir atau per kg + pendapatan',
              count: saleCount,
              countLabel: 'transaksi',
              onTap: () => _open(context, const EggSaleScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.account_balance,
              color: Colors.indigo,
              title: 'Keuangan',
              subtitle: 'Neraca arus kas: pemasukan, pengeluaran, saldo',
              count: cashCount,
              countLabel: 'transaksi kas',
              onTap: () => _open(context, const FinanceScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.badge,
              color: Colors.deepOrange,
              title: 'Register Ayam',
              subtitle: 'Identitas per ekor + foto profil',
              count: registryCount,
              countLabel: 'ekor',
              onTap: () => _open(context, const ChickenScreen()),
            ),
            const SizedBox(height: 12),
            _DataCard(
              icon: Icons.trending_up,
              color: Colors.purple,
              title: 'Produktivitas Ayam',
              subtitle: 'Telur/ekor/hari, laying rate, peringkat',
              count: registryCount,
              countLabel: 'ekor',
              onTap: () => _open(context, const ProductivityScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onSync});

  final int count;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count data belum terkirim ke server',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onSync,
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.countLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int count;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count $countLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
