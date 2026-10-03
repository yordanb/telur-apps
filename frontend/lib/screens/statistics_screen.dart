import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/egg_production_provider.dart';
import '../providers/chicken_management_provider.dart';
import '../providers/feed_record_provider.dart';
import '../providers/cost_record_provider.dart';
import '../providers/egg_sale_provider.dart';
import '../services/sync_service.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  Future<void> _loadData(WidgetRef ref) async {
    await SyncService.syncAll();
    await Future.wait([
      ref.read(eggProductionProvider.notifier).fetchProductions(),
      ref.read(chickenManagementProvider.notifier).fetchManagements(),
      ref.read(feedRecordProvider.notifier).fetchRecords(),
      ref.read(costRecordProvider.notifier).fetchRecords(),
      ref.read(eggSaleProvider.notifier).fetchSales(),
    ]);
    ref.invalidate(pendingCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEggProductionChart(context, ref),
              const SizedBox(height: 24),
              _buildSalesChart(context, ref),
              const SizedBox(height: 24),
              _buildChickenChart(context, ref),
              const SizedBox(height: 24),
              _buildCostChart(context, ref),
              const SizedBox(height: 24),
              _buildSummaryCards(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEggProductionChart(BuildContext context, WidgetRef ref) {
    final eggState = ref.watch(eggProductionProvider);
    final productions = eggState.productions.take(7).toList();

    if (productions.isEmpty) {
      return _buildEmptyChart(context, 'Produksi Telur');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produksi Telur (7 Hari Terakhir)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: productions.map((p) => p.totalEggs.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < productions.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd/MM').format(productions[index].date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: productions.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.totalEggs.toDouble(),
                          color: Colors.orange,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, WidgetRef ref) {
    final saleState = ref.watch(eggSaleProvider);

    final now = DateTime.now();
    final List<double> revenues = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final revenue = saleState.sales
          .where((s) => s.date.isAfter(dayStart) && s.date.isBefore(dayEnd))
          .fold<double>(0, (sum, s) => sum + s.totalPrice);

      revenues.add(revenue);
    }

    if (revenues.every((r) => r == 0)) {
      return _buildEmptyChart(context, 'Pendapatan');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pendapatan Penjualan (7 Hari Terakhir)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: revenues.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < 7) {
                            final date =
                                now.subtract(Duration(days: 6 - index));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toInt()}k',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: revenues.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: Colors.teal,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChickenChart(BuildContext context, WidgetRef ref) {
    final chickenState = ref.watch(chickenManagementProvider);
    final managements = chickenState.managements.take(7).toList();

    if (managements.isEmpty) {
      return _buildEmptyChart(context, 'Data Ayam');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jumlah Ayam (7 Hari Terakhir)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < managements.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd/MM').format(managements[index].date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: managements.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalChickens.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostChart(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedRecordProvider);
    final costState = ref.watch(costRecordProvider);

    // Calculate total costs for last 7 days
    final now = DateTime.now();
    final List<double> feedCosts = [];
    final List<double> otherCosts = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final feedCost = feedState.records
          .where((r) => r.date.isAfter(dayStart) && r.date.isBefore(dayEnd))
          .fold<double>(0, (sum, r) => sum + r.totalCost);

      final otherCost = costState.records
          .where((r) => r.date.isAfter(dayStart) && r.date.isBefore(dayEnd))
          .fold<double>(0, (sum, r) => sum + r.amount);

      feedCosts.add(feedCost);
      otherCosts.add(otherCost);
    }

    if (feedCosts.every((c) => c == 0) && otherCosts.every((c) => c == 0)) {
      return _buildEmptyChart(context, 'Biaya');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biaya (7 Hari Terakhir)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: [...feedCosts, ...otherCosts].reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < 7) {
                            final date = now.subtract(Duration(days: 6 - index));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toInt()}k',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: feedCosts[index],
                          color: Colors.brown,
                          width: 8,
                        ),
                        BarChartRodData(
                          toY: otherCosts[index],
                          color: Colors.red,
                          width: 8,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Pakan', Colors.brown),
                const SizedBox(width: 16),
                _buildLegendItem('Lainnya', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final eggState = ref.watch(eggProductionProvider);
    final chickenState = ref.watch(chickenManagementProvider);
    final feedState = ref.watch(feedRecordProvider);
    final costState = ref.watch(costRecordProvider);

    final totalEggs = eggState.productions.fold<int>(0, (sum, p) => sum + p.totalEggs);
    final totalChickens = chickenState.managements.isNotEmpty
        ? chickenState.managements.first.totalChickens
        : 0;
    final totalFeedCost = feedState.records.fold<double>(0, (sum, r) => sum + r.totalCost);
    final totalOtherCost = costState.records.fold<double>(0, (sum, r) => sum + r.amount);
    final saleState = ref.watch(eggSaleProvider);
    final totalRevenue = saleState.sales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final soldButir = saleState.sales
        .where((s) => s.unit == 'butir')
        .fold<double>(0, (sum, s) => sum + s.quantity);
    final soldKg = saleState.sales
        .where((s) => s.unit == 'kg')
        .fold<double>(0, (sum, s) => sum + s.quantity);

    final formatter = NumberFormat('#,###', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Total',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildSummaryCard(
              context,
              icon: Icons.egg,
              title: 'Total Telur',
              value: formatter.format(totalEggs),
              color: Colors.orange,
            ),
            _buildSummaryCard(
              context,
              icon: Icons.pets,
              title: 'Total Ayam',
              value: formatter.format(totalChickens),
              color: Colors.green,
            ),
            _buildSummaryCard(
              context,
              icon: Icons.grain,
              title: 'Total Biaya Pakan',
              value: 'Rp ${formatter.format(totalFeedCost)}',
              color: Colors.brown,
            ),
            _buildSummaryCard(
              context,
              icon: Icons.attach_money,
              title: 'Total Biaya Lain',
              value: 'Rp ${formatter.format(totalOtherCost)}',
              color: Colors.red,
            ),
            _buildSummaryCard(
              context,
              icon: Icons.payments,
              title: 'Total Pendapatan',
              value: 'Rp ${formatter.format(totalRevenue)}',
              color: Colors.teal,
            ),
            _buildSummaryCard(
              context,
              icon: Icons.shopping_cart,
              title: 'Telur Terjual',
              value:
                  '${formatter.format(soldButir)} butir • ${soldKg.toStringAsFixed(1)} kg',
              color: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('Belum ada data'),
          ],
        ),
      ),
    );
  }
}
