import 'package:flutter/material.dart';
import '../widgets/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/egg_sale_provider.dart';
import '../providers/cost_record_provider.dart';
import '../providers/cash_transaction_provider.dart';
import '../models/cost_record.dart';
import '../services/sync_service.dart';
import 'cash_transaction_screen.dart';

/// Keuangan — neraca arus kas.
///
/// Aturan hitung (disepakati):
/// - Pemasukan   = penjualan telur + transaksi kas masuk
/// - Pengeluaran = data Biaya (catatan Pakan TIDAK masuk kas agar tidak ganda)
///                 + transaksi kas keluar
/// - Saldo       = pemasukan − pengeluaran
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  /// Periode dalam hari; 0 = semua data.
  int _periodDays = 30;

  Future<void> _loadData() async {
    await SyncService.syncAll();
    await Future.wait([
      ref.read(eggSaleProvider.notifier).fetchSales(),
      ref.read(costRecordProvider.notifier).fetchRecords(),
      ref.read(cashTransactionProvider.notifier).fetchTransactions(),
    ]);
    ref.invalidate(pendingCountProvider);
  }

  bool _inPeriod(DateTime date, DateTime start) =>
      !date.isBefore(start);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final now = DateTime.now();
    final start = _periodDays == 0
        ? DateTime(2000)
        : DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: _periodDays - 1));

    final sales = ref
        .watch(eggSaleProvider.select((s) => s.sales))
        .where((e) => _inPeriod(e.date, start))
        .toList();
    final costs = ref
        .watch(costRecordProvider.select((s) => s.records))
        .where((e) => _inPeriod(e.date, start))
        .toList();
    final cash = ref
        .watch(cashTransactionProvider.select((s) => s.transactions))
        .where((e) => _inPeriod(e.date, start))
        .toList();

    final incomeEgg =
        sales.fold<double>(0, (sum, e) => sum + e.totalPrice);
    final incomeOther = cash
        .where((e) => e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final expenseCost =
        costs.fold<double>(0, (sum, e) => sum + e.amount);
    final expenseOther = cash
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final income = incomeEgg + incomeOther;
    final expense = expenseCost + expenseOther;
    final balance = income - expense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Transaksi Kas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CashTransactionScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveInsets.all(context, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodChips(
                value: _periodDays,
                onChanged: (v) => setState(() => _periodDays = v),
              ),
              const SizedBox(height: 12),
              _BalanceCard(
                income: income,
                expense: expense,
                balance: balance,
                formatter: formatter,
              ),
              const SizedBox(height: 24),
              _CashFlowChart(
                sales: sales,
                costs: costs,
                cash: cash,
                start: start,
                now: now,
                periodDays: _periodDays,
              ),
              const SizedBox(height: 24),
              _BreakdownCard(
                title: 'Rincian Pemasukan',
                color: Colors.green,
                entries: {
                  'Penjualan telur': incomeEgg,
                  ..._sumByCategory(
                      cash.where((e) => e.isIncome).toList()),
                },
                formatter: formatter,
              ),
              const SizedBox(height: 12),
              _BreakdownCard(
                title: 'Rincian Pengeluaran',
                color: Colors.red,
                entries: {
                  ..._sumCostByCategory(costs),
                  ..._sumByCategory(
                      cash.where((e) => !e.isIncome).toList()),
                },
                formatter: formatter,
              ),
              const SizedBox(height: 24),
              _RecentCashFlow(
                  sales: sales, costs: costs, cash: cash),
              const SizedBox(height: 8),
              Text(
                'Catatan: pengeluaran dihitung dari data Biaya (pembelian pakan termasuk). '
                'Pemberian pakan mengatur stok dan tidak memengaruhi kas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, double> _sumByCategory(List<dynamic> items) {
    final map = <String, double>{};
    for (final e in items) {
      map[e.category] =
          (map[e.category] ?? 0) + (e.amount as num).toDouble();
    }
    return map;
  }

  Map<String, double> _sumCostByCategory(List<dynamic> costs) {
    final map = <String, double>{};
    for (final e in costs) {
      var label = CostRecord.categoryLabel(e.category as String);
      final sub = e.subcategory as String?;
      if (sub != null && sub.isNotEmpty) label = '$label • $sub';
      map[label] = (map[label] ?? 0) + (e.amount as num).toDouble();
    }
    return map;
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {7: '7 hari', 30: '30 hari', 90: '90 hari', 0: 'Semua'};
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.formatter,
  });

  final double income;
  final double expense;
  final double balance;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0 ? Colors.green[700]! : Colors.red[700]!;
    return Card(
      child: Padding(
        padding: ResponsiveInsets.all(context, 16),
        child: Column(
          children: [
            const Text('Saldo Periode Ini',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              'Rp ${formatter.format(balance)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AmountColumn(
                    label: 'Pemasukan',
                    value: 'Rp ${formatter.format(income)}',
                    color: Colors.green,
                    icon: Icons.arrow_downward,
                  ),
                ),
                Expanded(
                  child: _AmountColumn(
                    label: 'Pengeluaran',
                    value: 'Rp ${formatter.format(expense)}',
                    color: Colors.red,
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({
    required this.sales,
    required this.costs,
    required this.cash,
    required this.start,
    required this.now,
    required this.periodDays,
  });

  final List<dynamic> sales;
  final List<dynamic> costs;
  final List<dynamic> cash;
  final DateTime start;
  final DateTime now;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final days = periodDays == 0
        ? _allDays()
        : List.generate(
            periodDays,
            (i) => DateTime(start.year, start.month, start.day)
                .add(Duration(days: i)));

    double incomeOn(DateTime day) {
      final next = day.add(const Duration(days: 1));
      var total = 0.0;
      for (final s in sales) {
        if (s.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
            s.date.isBefore(next)) {
          total += (s.totalPrice as num).toDouble();
        }
      }
      for (final t in cash) {
        if (t.isIncome &&
            t.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(next)) {
          total += (t.amount as num).toDouble();
        }
      }
      return total;
    }

    double expenseOn(DateTime day) {
      final next = day.add(const Duration(days: 1));
      var total = 0.0;
      for (final c in costs) {
        if (c.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
            c.date.isBefore(next)) {
          total += (c.amount as num).toDouble();
        }
      }
      for (final t in cash) {
        if (!t.isIncome &&
            t.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(next)) {
          total += (t.amount as num).toDouble();
        }
      }
      return total;
    }

    final incomes = days.map(incomeOn).toList();
    final expenses = days.map(expenseOn).toList();

    if (incomes.every((v) => v == 0) && expenses.every((v) => v == 0)) {
      return Card(
        child: Padding(
          padding: ResponsiveInsets.all(context, 16),
          child: Column(
            children: [
              Text('Arus Kas',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Belum ada data'),
            ],
          ),
        ),
      );
    }

    final maxY =
        [...incomes, ...expenses].reduce((a, b) => a > b ? a : b) * 1.2;
    final labelStep = (days.length / 7).ceil();

    return Card(
      child: Padding(
        padding: ResponsiveInsets.all(context, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arus Kas Harian',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY == 0 ? 1 : maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < days.length &&
                              index % labelStep == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('dd/MM')
                                    .format(days[index]),
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
                  barGroups: List.generate(days.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: incomes[index],
                          color: Colors.green,
                          width: 8,
                        ),
                        BarChartRodData(
                          toY: expenses[index],
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
                _LegendDot('Masuk', Colors.green),
                const SizedBox(width: 16),
                _LegendDot('Keluar', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Semua tanggal unik dari data (untuk mode "Semua"), maks 90 hari terakhir.
  List<DateTime> _allDays() {
    final dates = <DateTime>{};
    for (final e in [...sales, ...costs, ...cash]) {
      final d = (e.date as DateTime);
      dates.add(DateTime(d.year, d.month, d.day));
    }
    final sorted = dates.toList()..sort();
    if (sorted.length > 90) return sorted.sublist(sorted.length - 90);
    return sorted;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.color,
    required this.entries,
    required this.formatter,
  });

  final String title;
  final Color color;
  final Map<String, double> entries;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final total = entries.values.fold<double>(0, (a, b) => a + b);
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: ResponsiveInsets.all(context, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rp ${formatter.format(total)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              const Text('Belum ada data',
                  style: TextStyle(color: Colors.grey)),
            for (final e in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text('Rp ${formatter.format(e.value)}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentCashFlow extends StatelessWidget {
  const _RecentCashFlow({
    required this.sales,
    required this.costs,
    required this.cash,
  });

  final List<dynamic> sales;
  final List<dynamic> costs;
  final List<dynamic> cash;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final items = <_FlowItem>[
      for (final s in sales)
        _FlowItem(
          time: s.createdAt as DateTime,
          title: 'Penjualan telur (${s.unit})',
          income: true,
          amount: (s.totalPrice as num).toDouble(),
        ),
      for (final c in costs)
        _FlowItem(
          time: c.createdAt as DateTime,
          title:
              'Biaya ${CostRecord.categoryLabel(c.category as String)}',
          income: false,
          amount: (c.amount as num).toDouble(),
        ),
      for (final t in cash)
        _FlowItem(
          time: t.createdAt as DateTime,
          title: '${t.isIncome ? 'Kas masuk' : 'Kas keluar'} • ${t.category}',
          income: t.isIncome as bool,
          amount: (t.amount as num).toDouble(),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final recent = items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaksi Terakhir',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Belum ada transaksi')),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 60),
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: (recent[i].income
                              ? Colors.green
                              : Colors.red)
                          .withOpacity(0.15),
                      child: Icon(
                        recent[i].income
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: recent[i].income
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(recent[i].title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy • HH:mm')
                          .format(recent[i].time),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      '${recent[i].income ? '+' : '−'} Rp ${formatter.format(recent[i].amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: recent[i].income
                            ? Colors.green
                            : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FlowItem {
  _FlowItem({
    required this.time,
    required this.title,
    required this.income,
    required this.amount,
  });

  final DateTime time;
  final String title;
  final bool income;
  final double amount;
}
