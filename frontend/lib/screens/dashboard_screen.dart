import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer data loading to after first build to avoid
    // "setState() called during build" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final eggProvider = Provider.of<EggProductionProvider>(context, listen: false);
    final chickenProvider = Provider.of<ChickenManagementProvider>(context, listen: false);
    final feedProvider = Provider.of<FeedRecordProvider>(context, listen: false);
    final costProvider = Provider.of<CostRecordProvider>(context, listen: false);

    await Future.wait([
      eggProvider.fetchProductions(),
      chickenProvider.fetchManagements(),
      feedProvider.fetchRecords(),
      costProvider.fetchRecords(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final List<Widget> screens = [
      _buildHomeScreen(),
      const EggProductionScreen(),
      const ChickenManagementScreen(),
      const FeedRecordScreen(),
      const CostRecordScreen(),
      const StatisticsScreen(),
    ];

    // Add user management screen for admin
    if (user?.isAdmin == true) {
      screens.add(const UserManagementScreen());
    }

    final List<BottomNavigationBarItem> navItems = [
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

  Widget _buildHomeScreen() {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Just logout - the Consumer in main.dart will
              // automatically switch back to LoginScreen
              await auth.logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<EggProductionProvider>(
                builder: (context, eggProvider, _) {
                  final today = DateTime.now();
                  final todayProductions = eggProvider.productions.where((p) {
                    return p.date.year == today.year &&
                        p.date.month == today.month &&
                        p.date.day == today.day;
                  }).toList();

                  final totalEggs = todayProductions.fold<int>(
                    0,
                    (sum, p) => sum + p.totalEggs,
                  );

                  return _buildStatCard(
                    icon: Icons.egg,
                    title: 'Total Telur Hari Ini',
                    value: totalEggs.toString(),
                    color: Colors.orange,
                  );
                },
              ),
              const SizedBox(height: 12),
              Consumer<ChickenManagementProvider>(
                builder: (context, chickenProvider, _) {
                  final today = DateTime.now();
                  final todayManagement = chickenProvider.managements.where((m) {
                    return m.date.year == today.year &&
                        m.date.month == today.month &&
                        m.date.day == today.day;
                  }).toList();

                  final totalChickens = todayManagement.isNotEmpty
                      ? todayManagement.first.totalChickens
                      : 0;

                  return _buildStatCard(
                    icon: Icons.pets,
                    title: 'Total Ayam',
                    value: totalChickens.toString(),
                    color: Colors.green,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Aksi Cepat',
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
                  _buildQuickAction(
                    icon: Icons.add,
                    title: 'Catat Produksi',
                    color: Colors.orange,
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.pets,
                    title: 'Kelola Ayam',
                    color: Colors.green,
                    onTap: () {
                      setState(() {
                        _selectedIndex = 2;
                      });
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.grain,
                    title: 'Catat Pakan',
                    color: Colors.brown,
                    onTap: () {
                      setState(() {
                        _selectedIndex = 3;
                      });
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.attach_money,
                    title: 'Catat Biaya',
                    color: Colors.red,
                    onTap: () {
                      setState(() {
                        _selectedIndex = 4;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
