import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chicken_management_provider.dart';
import '../models/chicken_management.dart';

class ChickenManagementScreen extends StatefulWidget {
  const ChickenManagementScreen({super.key});

  @override
  State<ChickenManagementScreen> createState() => _ChickenManagementScreenState();
}

class _ChickenManagementScreenState extends State<ChickenManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChickenManagementProvider>(context, listen: false).fetchManagements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Ayam'),
      ),
      body: Consumer<ChickenManagementProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchManagements(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (provider.managements.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada data manajemen ayam'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchManagements(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.managements.length,
              itemBuilder: (context, index) {
                final management = provider.managements[index];
                return _buildManagementCard(management, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildManagementCard(ChickenManagement management, ChickenManagementProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy').format(management.date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, management);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, management, provider);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.pets,
                  label: 'Total',
                  value: '${management.totalChickens}',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.favorite,
                  label: 'Sehat',
                  value: '${management.healthyChickens}',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.sick,
                  label: 'Sakit',
                  value: '${management.sickChickens}',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.heart_broken,
                  label: 'Mati',
                  value: '${management.deadChickens}',
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.add_circle,
                  label: 'Baru',
                  value: '${management.newChickens}',
                  color: Colors.purple,
                ),
              ],
            ),
            if (management.notes != null && management.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${management.notes}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final totalChickensController = TextEditingController();
    final healthyChickensController = TextEditingController();
    final sickChickensController = TextEditingController();
    final deadChickensController = TextEditingController();
    final newChickensController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Manajemen Ayam'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal (YYYY-MM-DD)'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalChickensController,
                decoration: const InputDecoration(labelText: 'Total Ayam'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: healthyChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Sehat'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sickChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Sakit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deadChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Mati'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Baru'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final management = ChickenManagement(
                id: 0,
                userId: 0,
                date: DateTime.parse(dateController.text),
                totalChickens: int.parse(totalChickensController.text),
                healthyChickens: int.parse(healthyChickensController.text),
                sickChickens: int.tryParse(sickChickensController.text) ?? 0,
                deadChickens: int.tryParse(deadChickensController.text) ?? 0,
                newChickens: int.tryParse(newChickensController.text) ?? 0,
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: DateTime.now(),
              );

              final provider = Provider.of<ChickenManagementProvider>(context, listen: false);
              final success = await provider.createManagement(management);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Data berhasil ditambahkan' : 'Gagal menambahkan data'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChickenManagement management) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(management.date));
    final totalChickensController = TextEditingController(text: management.totalChickens.toString());
    final healthyChickensController = TextEditingController(text: management.healthyChickens.toString());
    final sickChickensController = TextEditingController(text: management.sickChickens.toString());
    final deadChickensController = TextEditingController(text: management.deadChickens.toString());
    final newChickensController = TextEditingController(text: management.newChickens.toString());
    final notesController = TextEditingController(text: management.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Manajemen Ayam'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal (YYYY-MM-DD)'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: management.date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalChickensController,
                decoration: const InputDecoration(labelText: 'Total Ayam'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: healthyChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Sehat'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sickChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Sakit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deadChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Mati'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newChickensController,
                decoration: const InputDecoration(labelText: 'Ayam Baru'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedManagement = ChickenManagement(
                id: management.id,
                userId: management.userId,
                date: DateTime.parse(dateController.text),
                totalChickens: int.parse(totalChickensController.text),
                healthyChickens: int.parse(healthyChickensController.text),
                sickChickens: int.tryParse(sickChickensController.text) ?? 0,
                deadChickens: int.tryParse(deadChickensController.text) ?? 0,
                newChickens: int.tryParse(newChickensController.text) ?? 0,
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: management.createdAt,
              );

              final provider = Provider.of<ChickenManagementProvider>(context, listen: false);
              final success = await provider.updateManagement(management.id, updatedManagement);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Data berhasil diupdate' : 'Gagal mengupdate data'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChickenManagement management, ChickenManagementProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await provider.deleteManagement(management.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Data berhasil dihapus' : 'Gagal menghapus data'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
