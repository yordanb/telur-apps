import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/egg_production_provider.dart';
import '../providers/chicken_management_provider.dart';
import '../providers/feed_record_provider.dart';
import '../providers/cost_record_provider.dart';
import 'egg_production_screen.dart';
import 'chicken_management_screen.dart';
import 'feed_record_screen.dart';
import 'cost_record_screen.dart';
import 'statistics_screen.dart';
import 'data_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  static const int _productionTab = 1;
  static const int _dataTab = 2;

  @override
  void initState() {
    super.initState();
    // Defer to after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    ref.read(eggProductionProvider.notifier).fetchProductions();
    ref.read(chickenManagementProvider.notifier).fetchManagements();
    ref.read(feedRecordProvider.notifier).fetchRecords();
    ref.read(costRecordProvider.notifier).fetchRecords();
  }

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeScreen(),
      const EggProductionScreen(),
      const DataScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _goToTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.egg_outlined),
            activeIcon: Icon(Icons.egg),
            label: 'Produksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  HOME (BERANDA) — Option 1: Hero CTA + Riwayat
  //  A. Sapaan + tanggal
  //  B. 3 KPI sejajar (Telur / Ayam / Pakan)
  //  C. Hero CTA "Catat Produksi Hari Ini"
  //  D. Baris ikon aksi (Ayam / Pakan / Biaya)
  //  E. Aktivitas Terakhir (5 item terbaru)
  // ============================================================
  Widget _buildHomeScreen() {
    return Scaffold(
      appBar: AppBar(
          //title: const Text('Beranda'),
          ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingHeader(), // A
              const SizedBox(height: 16),
              _buildKpiRow(), // B
              const SizedBox(height: 16),
              _buildHeroCta(), // C
              const SizedBox(height: 16),
              _buildActionRow(), // D
              const SizedBox(height: 24),
              _buildRecentActivity(), // E
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- A. Sapaan + tanggal ----------
  Widget _buildGreetingHeader() {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final now = DateTime.now();
    final hour = now.hour;

    String greeting;
    if (hour >= 4 && hour < 11) {
      greeting = 'Selamat pagi';
    } else if (hour >= 11 && hour < 15) {
      greeting = 'Selamat siang';
    } else if (hour >= 15 && hour < 19) {
      greeting = 'Selamat sore';
    } else {
      greeting = 'Selamat malam';
    }

    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                user?.fullName ?? 'User',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ---------- B. 3 KPI sejajar ----------
  Widget _buildKpiRow() {
    final today = DateTime.now();

    // Telur hari ini
    final eggState = ref.watch(eggProductionProvider);
    final todayEggs = eggState.productions
        .where((p) => _isSameDay(p.date, today))
        .fold<int>(0, (sum, p) => sum + p.totalEggs);

    // Ayam (hari ini, atau data terbaru jika belum ada catatan hari ini)
    final chickenState = ref.watch(chickenManagementProvider);
    final todayChicken = chickenState.managements
        .where((m) => _isSameDay(m.date, today))
        .toList();
    final int totalChickens = todayChicken.isNotEmpty
        ? todayChicken.first.totalChickens
        : (chickenState.managements.isNotEmpty
            ? chickenState.managements.first.totalChickens
            : 0);

    // Pakan hari ini (kg)
    final feedState = ref.watch(feedRecordProvider);
    final todayFeedKg = feedState.records
        .where((r) => _isSameDay(r.date, today))
        .fold<double>(0, (sum, r) => sum + r.quantityKg);

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.egg,
            color: Colors.orange,
            value: todayEggs.toString(),
            label: 'Telur hari ini',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            icon: Icons.pets,
            color: Colors.green,
            value: totalChickens.toString(),
            label: 'Ayam',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            icon: Icons.grain,
            color: Colors.brown,
            value: '${todayFeedKg.toStringAsFixed(1)} kg',
            label: 'Pakan hari ini',
          ),
        ),
      ],
    );
  }

  // ---------- C. Hero CTA ----------
  Widget _buildHeroCta() {
    final today = DateTime.now();
    final eggState = ref.watch(eggProductionProvider);
    final todayProductions =
        eggState.productions.where((p) => _isSameDay(p.date, today)).toList();
    final hasRecord = todayProductions.isNotEmpty;
    final todayEggs =
        todayProductions.fold<int>(0, (sum, p) => sum + p.totalEggs);

    // Warna mengikuti tema yang dipilih di Pengaturan
    final primary = Theme.of(context).colorScheme.primary;
    final dark = Color.lerp(primary, Colors.black, 0.25)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _goToTab(_productionTab),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.egg,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CATAT PRODUKSI HARI INI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasRecord
                            ? 'Sudah $todayEggs telur — ketuk untuk perbarui'
                            : 'Belum dicatat — ketuk untuk mulai',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasRecord ? Icons.edit : Icons.add,
                    color: dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- D. Baris ikon aksi ----------
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.pets,
            color: Colors.green,
            label: 'Ayam',
            onTap: () => _openScreen(const ChickenManagementScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.grain,
            color: Colors.brown,
            label: 'Pakan',
            onTap: () => _openScreen(const FeedRecordScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.attach_money,
            color: Colors.red,
            label: 'Biaya',
            onTap: () => _openScreen(const CostRecordScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.folder,
            color: Colors.blueGrey,
            label: 'Data',
            onTap: () => _goToTab(_dataTab),
          ),
        ),
      ],
    );
  }

  // ---------- E. Aktivitas Terakhir ----------
  Widget _buildRecentActivity() {
    final activities = _recentActivities();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aktivitas Terakhir',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _goToTab(_dataTab),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        if (activities.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada aktivitas',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < activities.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 60),
                  _buildActivityTile(activities[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityTile(_ActivityItem item) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: item.color.withOpacity(0.15),
        child: Icon(item.icon, color: item.color, size: 20),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        item.value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: item.color,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Gabungkan produksi telur, pakan, dan biaya → urutkan terbaru → 5 teratas
  List<_ActivityItem> _recentActivities() {
    final eggs = ref.watch(eggProductionProvider.select((s) => s.productions));
    final feeds = ref.watch(feedRecordProvider.select((s) => s.records));
    final costs = ref.watch(costRecordProvider.select((s) => s.records));
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm');

    final items = <_ActivityItem>[
      ...eggs.map((p) => _ActivityItem(
            time: p.createdAt,
            icon: Icons.egg,
            color: Colors.orange,
            title: 'Produksi Telur',
            subtitle: dateFormat.format(p.createdAt),
            value: '${p.totalEggs} telur',
          )),
      ...feeds.map((r) => _ActivityItem(
            time: r.createdAt,
            icon: Icons.grain,
            color: Colors.brown,
            title: 'Pakan ${r.feedType}',
            subtitle: dateFormat.format(r.createdAt),
            value: '${r.quantityKg} kg',
          )),
      ...costs.map((r) => _ActivityItem(
            time: r.createdAt,
            icon: Icons.attach_money,
            color: Colors.red,
            title: 'Biaya ${r.category}',
            subtitle: dateFormat.format(r.createdAt),
            value: 'Rp ${NumberFormat('#,###', 'id_ID').format(r.amount)}',
          )),
    ];

    items.sort((a, b) => b.time.compareTo(a.time));
    return items.take(5).toList();
  }
}

// ============================================================
//  Helper widgets
// ============================================================

class _ActivityItem {
  const _ActivityItem({
    required this.time,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final DateTime time;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String value;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
