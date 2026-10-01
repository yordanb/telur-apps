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
import 'user_management_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    final screens = [
      _buildHomeScreen(auth),
      const EggProductionScreen(),
      const ChickenManagementScreen(),
      const FeedRecordScreen(),
      const CostRecordScreen(),
      const StatisticsScreen(),
    ];

    if (user?.isAdmin == true) {
      screens.add(const UserManagementScreen());
    }

    final navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Beranda',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.egg),
        label: 'Produksi',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.pets),
        label: 'Ayam',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.grain),
        label: 'Pakan',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.attach_money),
        label: 'Biaya',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart),
        label: 'Statistik',
      ),
    ];

    if (user?.isAdmin == true) {
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'User',
      ));
    }

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }

  Widget _buildHomeScreen(AuthState auth) {
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Just logout - GoRouter redirect will switch to LoginScreen
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
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
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  _buildQuickAction(
                    icon: Icons.pets,
                    title: 'Kelola Ayam',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  _buildQuickAction(
                    icon: Icons.grain,
                    title: 'Catat Pakan',
                    color: Colors.brown,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                  _buildQuickAction(
                    icon: Icons.attach_money,
                    title: 'Catat Biaya',
                    color: Colors.red,
                    onTap: () => setState(() => _selectedIndex = 4),
                  ),
                ],
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
