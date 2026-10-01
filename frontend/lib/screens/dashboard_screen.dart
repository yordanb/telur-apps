import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Widget _buildHomeScreen() {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selamat datang,',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              user?.fullName ?? 'User',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user?.isAdmin == true
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user?.isAdmin == true ? 'Admin' : 'Pegawai',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: user?.isAdmin == true
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats
              Text(
                'Ringkasan Hari Ini',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildEggStatCard(),
              const SizedBox(height: 12),
              _buildChickenStatCard(),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Aksi Cepat',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildQuickAction(
                    icon: Icons.add,
                    title: 'Catat Produksi',
                    color: Colors.orange,
                    onTap: () => _goToTab(_productionTab),
                  ),
                  _buildQuickAction(
                    icon: Icons.pets,
                    title: 'Kelola Ayam',
                    color: Colors.green,
                    onTap: () => _openScreen(const ChickenManagementScreen()),
                  ),
                  _buildQuickAction(
                    icon: Icons.grain,
                    title: 'Catat Pakan',
                    color: Colors.brown,
                    onTap: () => _openScreen(const FeedRecordScreen()),
                  ),
                  _buildQuickAction(
                    icon: Icons.attach_money,
                    title: 'Catat Biaya',
                    color: Colors.red,
                    onTap: () => _openScreen(const CostRecordScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Shortcut to Data tab
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _goToTab(_dataTab),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Lihat semua data di tab Data',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEggStatCard() {
    final eggState = ref.watch(eggProductionProvider);
    final today = DateTime.now();
    final todayProductions = eggState.productions.where((p) {
      return p.date.year == today.year &&
          p.date.month == today.month &&
          p.date.day == today.day;
    }).toList();
    final totalEggs =
        todayProductions.fold<int>(0, (sum, p) => sum + p.totalEggs);

    return _buildStatCard(
      icon: Icons.egg,
      title: 'Total Telur Hari Ini',
      value: totalEggs.toString(),
      color: Colors.orange,
    );
  }

  Widget _buildChickenStatCard() {
    final chickenState = ref.watch(chickenManagementProvider);
    final today = DateTime.now();
    final todayManagement = chickenState.managements.where((m) {
      return m.date.year == today.year &&
          m.date.month == today.month &&
          m.date.day == today.day;
    }).toList();
    final totalChickens =
        todayManagement.isNotEmpty ? todayManagement.first.totalChickens : 0;

    return _buildStatCard(
      icon: Icons.pets,
      title: 'Total Ayam',
      value: totalChickens.toString(),
      color: Colors.green,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
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
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
