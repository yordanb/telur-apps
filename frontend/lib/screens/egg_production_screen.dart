import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/egg_production_provider.dart';
import '../models/egg_production.dart';

class EggProductionScreen extends ConsumerWidget {
  const EggProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eggProductionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produksi Telur'),
      ),
      body: _buildBody(context, ref, state),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, EggProductionState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.productions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(eggProductionProvider.notifier).fetchProductions(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.productions.isEmpty) {
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
      onRefresh: () =>
          ref.read(eggProductionProvider.notifier).fetchProductions(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.productions.length,
        itemBuilder: (context, index) {
          final production = state.productions[index];
          return _buildProductionCard(context, ref, production);
        },
      ),
    );
  }

  Widget _buildProductionCard(
      BuildContext context, WidgetRef ref, EggProduction production) {
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, ref, production);
                    } else {
                      _showDeleteDialog(context, ref, production);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                    Icons.egg, 'Total', '${production.totalEggs}',
                    Colors.orange),
                const SizedBox(width: 8),
                _buildInfoChip(
                    Icons.check_circle, 'Baik', '${production.goodEggs}',
                    Colors.green),
                const SizedBox(width: 8),
                _buildInfoChip(
                    Icons.cancel, 'Rusak', '${production.badEggs}',
                    Colors.red),
              ],
            ),
            if (production.weightAvg != null) ...[
              const SizedBox(height: 8),
              Text('Rata-rata berat: ${production.weightAvg} gram',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (production.notes != null && production.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catatan: ${production.notes}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final dateController =
        TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final totalEggsController = TextEditingController();
    final goodEggsController = TextEditingController();
    final badEggsController = TextEditingController();
    final weightAvgController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Produksi Telur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogContext,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                }),
            const SizedBox(height: 8),
            TextField(
                controller: totalEggsController,
                decoration: const InputDecoration(labelText: 'Total Telur'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: goodEggsController,
                decoration: const InputDecoration(labelText: 'Telur Baik'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: badEggsController,
                decoration: const InputDecoration(labelText: 'Telur Rusak'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: weightAvgController,
                decoration:
                    const InputDecoration(labelText: 'Berat (gram)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal')),
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
              final success = await ref
                  .read(eggProductionProvider.notifier)
                  .createProduction(production);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Data berhasil ditambahkan'
                      : 'Gagal menambahkan data'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, EggProduction production) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(production.date));
    final totalEggsController =
        TextEditingController(text: production.totalEggs.toString());
    final goodEggsController =
        TextEditingController(text: production.goodEggs.toString());
    final badEggsController =
        TextEditingController(text: production.badEggs.toString());
    final weightAvgController =
        TextEditingController(text: production.weightAvg?.toString() ?? '');
    final notesController =
        TextEditingController(text: production.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Produksi Telur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogContext,
                    initialDate: production.date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                }),
            const SizedBox(height: 8),
            TextField(
                controller: totalEggsController,
                decoration: const InputDecoration(labelText: 'Total Telur'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: goodEggsController,
                decoration: const InputDecoration(labelText: 'Telur Baik'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: badEggsController,
                decoration: const InputDecoration(labelText: 'Telur Rusak'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: weightAvgController,
                decoration:
                    const InputDecoration(labelText: 'Berat (gram)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final updated = EggProduction(
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
              final success = await ref
                  .read(eggProductionProvider.notifier)
                  .updateProduction(production.id, updated);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Data berhasil diupdate'
                      : 'Gagal mengupdate data'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, EggProduction production) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(eggProductionProvider.notifier)
                  .deleteProduction(production.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Data berhasil dihapus'
                      : 'Gagal menghapus data'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
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
