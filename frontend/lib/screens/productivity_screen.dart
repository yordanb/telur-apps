import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/egg_production_provider.dart';
import '../providers/chicken_provider.dart';
import '../models/chicken.dart';
import '../services/api_service.dart';

/// Produktivitas ayam per ekor.
///
/// - Total telur = jumlah rincian ayam pada periode
/// - Rata-rata = total / hari hadir
/// - Laying rate = total / hari hadir × 100% (hen-day)
/// Hari hadir = dari maks(awal periode, tanggal masuk ayam) s.d. hari ini.
/// Ayam non-aktif tetap ditampilkan tanpa peringkat.
class ProductivityScreen extends ConsumerStatefulWidget {
  const ProductivityScreen({super.key});

  @override
  ConsumerState<ProductivityScreen> createState() =>
      _ProductivityScreenState();
}

class _ProductivityScreenState
    extends ConsumerState<ProductivityScreen> {
  int _periodDays = 30; // 0 = semua

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = _periodDays == 0
        ? DateTime(2000)
        : today.subtract(Duration(days: _periodDays - 1));

    final productions = ref.watch(
        eggProductionProvider.select((s) => s.productions));
    final chickens =
        ref.watch(chickenProvider.select((s) => s.chickens));

    // Agregat telur per ayam pada periode.
    final eggsByChicken = <int, int>{};
    for (final p in productions) {
      if (p.date.isBefore(periodStart)) continue;
      for (final d in p.details) {
        eggsByChicken[d.chickenId] =
            (eggsByChicken[d.chickenId] ?? 0) + d.eggs;
      }
    }

    final stats = <_ChickenStat>[];
    for (final c in chickens) {
      final from = c.acquiredDate != null &&
              c.acquiredDate!.isAfter(periodStart)
          ? DateTime(c.acquiredDate!.year, c.acquiredDate!.month,
              c.acquiredDate!.day)
          : periodStart;
      var days = today.difference(from).inDays + 1;
      if (days < 1) days = 1;
      final total = eggsByChicken[c.id] ?? 0;
      stats.add(_ChickenStat(
        chicken: c,
        total: total,
        days: days,
        avg: total / days,
        rate: total / days * 100,
      ));
    }

    final active =
        stats.where((s) => s.chicken.isActive).toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    final inactive =
        stats.where((s) => !s.chicken.isActive).toList()
          ..sort((a, b) => b.total.compareTo(a.total));

    final top = active.where((s) => s.total > 0).take(5).toList();
    final bottom = active.reversed.take(5).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produktivitas Ayam'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(eggProductionProvider.notifier).fetchProductions(),
            ref.read(chickenProvider.notifier).fetchChickens(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in {
                    7: '7 hari',
                    30: '30 hari',
                    90: '90 hari',
                    0: 'Semua'
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _periodDays == entry.key,
                      onSelected: (_) =>
                          setState(() => _periodDays = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (active.isEmpty && inactive.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text(
                            'Belum ada ayam terdaftar. Daftarkan dulu di Register Ayam.')),
                  ),
                )
              else ...[
                if (top.isNotEmpty) ...[
                  _SectionTitle('Paling Produktif',
                      Icons.emoji_events, Colors.amber),
                  const SizedBox(height: 8),
                  for (final s in top)
                    _StatCard(stat: s, formatter: formatter, rank: true),
                  const SizedBox(height: 16),
                ],
                if (bottom.isNotEmpty &&
                    bottom.length > 1) ...[
                  _SectionTitle('Perlu Perhatian',
                      Icons.warning_amber, Colors.orange),
                  const SizedBox(height: 8),
                  for (final s in bottom)
                    _StatCard(stat: s, formatter: formatter),
                  const SizedBox(height: 16),
                ],
                _SectionTitle(
                    'Semua Ayam', Icons.pets, Colors.green),
                const SizedBox(height: 8),
                for (final s in [...active, ...inactive])
                  _StatCard(stat: s, formatter: formatter),
                const SizedBox(height: 8),
                Text(
                  'Laying rate = telur ÷ hari hadir × 100%. '
                  'Hari hadir dihitung sejak awal periode atau tanggal masuk ayam. '
                  'Riwayat sakit/mati belum memotong hari hadir.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChickenStat {
  _ChickenStat({
    required this.chicken,
    required this.total,
    required this.days,
    required this.avg,
    required this.rate,
  });

  final Chicken chicken;
  final int total;
  final int days;
  final double avg;
  final double rate;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.stat,
    required this.formatter,
    this.rank = false,
  });

  final _ChickenStat stat;
  final NumberFormat formatter;
  final bool rank;

  @override
  Widget build(BuildContext context) {
    final c = stat.chicken;
    final photoUrl = ApiService.photoUrl(c.photoPath);
    final barValue = (stat.rate / 100).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.orange.withOpacity(0.15),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              onBackgroundImageError:
                  photoUrl.isNotEmpty ? (_, __) {} : null,
              child: photoUrl.isEmpty
                  ? Text(
                      c.code.isNotEmpty ? c.code[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rank)
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                      if (rank) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Text(
                        '${formatter.format(stat.total)} butir',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barValue,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stat.rate >= 70
                            ? Colors.green
                            : stat.rate >= 40
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stat.avg.toStringAsFixed(2)} butir/hari • '
                    'laying rate ${stat.rate.toStringAsFixed(1)}% '
                    '• ${stat.days} hari',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
