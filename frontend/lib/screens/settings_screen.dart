import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_color_provider.dart';
import '../services/api_service.dart';
import '../utils/notification_service.dart';
import 'user_management_screen.dart';

/// Tab "Pengaturan" — profil, notifikasi, manajemen user (admin),
/// info aplikasi & server, serta logout.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kReminderEnabled = 'daily_reminder_enabled';
  static const _kReminderHour = 'daily_reminder_hour';
  static const int _defaultReminderHour = 7;

  bool _reminderEnabled = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = prefs.getBool(_kReminderEnabled) ?? false;
      _prefsLoaded = true;
    });
  }

  Future<void> _toggleReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_kReminderHour) ?? _defaultReminderHour;

    if (enabled) {
      await NotificationService.scheduleDailyReminder(hour: hour, minute: 0);
    } else {
      await NotificationService.cancelAll();
    }
    await prefs.setBool(_kReminderEnabled, enabled);

    if (!mounted) return;
    setState(() => _reminderEnabled = enabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled
            ? 'Pengingat harian diaktifkan (setiap pukul $hour:00)'
            : 'Pengingat harian dinonaktifkan'),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // GoRouter redirect will automatically switch to LoginScreen
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isAdmin = user?.isAdmin == true;
    final themeState = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ Profil ============
          _SectionLabel('Profil'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '-',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user?.username ?? '-'}',
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
                            color: isAdmin
                                ? Colors.orange[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAdmin ? 'Admin' : 'Pegawai',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isAdmin ? Colors.orange[800] : Colors.blue[800],
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
          const SizedBox(height: 16),

          // ============ Notifikasi ============
          _SectionLabel('Notifikasi'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active,
                  color: Colors.amber),
              title: const Text('Pengingat Harian'),
              subtitle: Text(_prefsLoaded
                  ? _reminderEnabled
                      ? 'Setiap pukul $_defaultReminderHour:00 — jangan lupa catat produksi'
                      : 'Nonaktif'
                  : 'Memuat...'),
              value: _reminderEnabled,
              onChanged: _prefsLoaded ? _toggleReminder : null,
            ),
          ),
          const SizedBox(height: 16),

          // ============ Tema Aplikasi ============
          _SectionLabel('Tema Aplikasi'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (int i = 0; i < themeColorOptions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _ColorChoice(
                        color: themeColorOptions[i].seed,
                        label: themeColorOptions[i].name,
                        selected: themeState.index == i,
                        onTap: () => ref
                            .read(themeColorProvider.notifier)
                            .select(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ============ Manajemen User (admin only) ============
          if (isAdmin) ...[
            _SectionLabel('Administrasi'),
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.people, color: Colors.deepPurple),
                title: const Text('Manajemen User'),
                subtitle: const Text('Tambah dan lihat pegawai / admin'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ============ Info Aplikasi & Server ============
          _SectionLabel('Info Aplikasi & Server'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blue),
                  title: Text('Versi Aplikasi'),
                  trailing: Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns, color: Colors.teal),
                  title: const Text('Server API'),
                  subtitle: Text(ApiService.baseUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.cloud_done, color: Colors.green),
                  title: const Text('Mode'),
                  subtitle: const Text('Online + Offline (sinkron otomatis)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ============ Logout ============
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
      ),
    );
  }
}

/// Satu pilihan warna tema (bulatan warna + label + centang jika terpilih).
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
