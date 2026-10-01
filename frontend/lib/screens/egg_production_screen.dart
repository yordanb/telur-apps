import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/egg_production_provider.dart';
import '../models/egg_production.dart';

class EggProductionScreen extends StatefulWidget {
  const EggProductionScreen({super.key});

  @override
  State<EggProductionScreen> createState() => _EggProductionScreenState();
}

class _EggProductionScreenState extends State<EggProductionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EggProductionProvider>(context, listen: false).fetchProductions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produksi Telur'),
      ),
      body: Consumer<EggProductionProvider>(
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
                    onPressed: () => provider.fetchProductions(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          if (provider.productions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada data produksi telur'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchProductions(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.productions.length,
              itemBuilder: (context, index) {
                final production = provider.productions[index];
                return _buildProductionCard(production, provider);
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

  Widget _buildProductionCard(EggProduction production, EggProductionProvider provider) {
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
                  DateFormat('dd MMMM yyyy').format(production.date),
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
                      _showEditDialog(context, production);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, production, provider);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.egg,
                  label: 'Total',
                  value: '${production.totalEggs}',
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.check_circle,
                  label: 'Baik',
                  value: '${production.goodEggs}',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.cancel,
                  label: 'Rusak',
                  value: '${production.badEggs}',
                  color: Colors.red,
                ),
              ],
            ),
            if (production.weightAvg != null) ...[
              const SizedBox(height: 8),
              Text(
                'Rata-rata berat: ${production.weightAvg} gram',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (production.notes != null && production.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${production.notes}',
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
    final totalEggsController = TextEditingController();
    final goodEggsController = TextEditingController();
    final badEggsController = TextEditingController();
    final weightAvgController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Produksi Telur'),
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
                controller: totalEggsController,
                decoration: const InputDecoration(labelText: 'Total Telur'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: goodEggsController,
                decoration: const InputDecoration(labelText: 'Telur Baik'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: badEggsController,
                decoration: const InputDecoration(labelText: 'Telur Rusak'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightAvgController,
                decoration: const InputDecoration(labelText: 'Rata-rata Berat (gram)'),
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
              final production = EggProduction(
                id: 0,
                userId: 0,
                date: DateTime.parse(dateController.text),
                totalEggs: int.parse(totalEggsController.text),
                goodEggs: int.parse(goodEggsController.text),
                badEggs: int.tryParse(badEggsController.text) ?? 0,
                weightAvg: double.tryParse(weightAvgController.text),
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: DateTime.now(),
              );

              final provider = Provider.of<EggProductionProvider>(context, listen: false);
              final success = await provider.createProduction(production);

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

  void _showEditDialog(BuildContext context, EggProduction production) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(production.date));
    final totalEggsController = TextEditingController(text: production.totalEggs.toString());
    final goodEggsController = TextEditingController(text: production.goodEggs.toString());
    final badEggsController = TextEditingController(text: production.badEggs.toString());
    final weightAvgController = TextEditingController(text: production.weightAvg?.toString() ?? '');
    final notesController = TextEditingController(text: production.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Produksi Telur'),
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
                    initialDate: production.date,
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
                controller: totalEggsController,
                decoration: const InputDecoration(labelText: 'Total Telur'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: goodEggsController,
                decoration: const InputDecoration(labelText: 'Telur Baik'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: badEggsController,
                decoration: const InputDecoration(labelText: 'Telur Rusak'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightAvgController,
                decoration: const InputDecoration(labelText: 'Rata-rata Berat (gram)'),
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
              final updatedProduction = EggProduction(
                id: production.id,
                userId: production.userId,
                date: DateTime.parse(dateController.text),
                totalEggs: int.parse(totalEggsController.text),
                goodEggs: int.parse(goodEggsController.text),
                badEggs: int.tryParse(badEggsController.text) ?? 0,
                weightAvg: double.tryParse(weightAvgController.text),
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: production.createdAt,
              );

              final provider = Provider.of<EggProductionProvider>(context, listen: false);
              final success = await provider.updateProduction(production.id, updatedProduction);

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

  void _showDeleteDialog(BuildContext context, EggProduction production, EggProductionProvider provider) {
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
              final success = await provider.deleteProduction(production.id);
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
