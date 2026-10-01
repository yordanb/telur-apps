import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/chicken_management_provider.dart';
import '../providers/auth_provider.dart';
import '../models/chicken_management.dart';

class ChickenManagementScreen extends ConsumerWidget {
  const ChickenManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chickenManagementProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Ayam')),
      body: _buildBody(context, ref, state),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      ChickenManagementState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.managements.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(state.error!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref
                .read(chickenManagementProvider.notifier)
                .fetchManagements(),
            child: const Text('Coba Lagi'),
          ),
        ]),
      );
    }

    if (state.managements.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.pets, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada data manajemen ayam'),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(chickenManagementProvider.notifier).fetchManagements(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.managements.length,
        itemBuilder: (context, index) {
          final management = state.managements[index];
          return _buildCard(context, ref, management);
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref,
      ChickenManagement management) {
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              DateFormat('dd MMMM yyyy').format(management.date),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (canEdit)
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
                    _showEditDialog(context, ref, management);
                  } else {
                    _showDeleteDialog(context, ref, management);
                  }
                },
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _buildChip(Icons.pets, 'Total', '${management.totalChickens}',
                Colors.blue),
            const SizedBox(width: 8),
            _buildChip(Icons.favorite, 'Sehat',
                '${management.healthyChickens}', Colors.green),
            const SizedBox(width: 8),
            _buildChip(Icons.sick, 'Sakit', '${management.sickChickens}',
                Colors.orange),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _buildChip(Icons.heart_broken, 'Mati',
                '${management.deadChickens}', Colors.red),
            const SizedBox(width: 8),
            _buildChip(Icons.add_circle, 'Baru',
                '${management.newChickens}', Colors.purple),
          ]),
          if (management.notes != null && management.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${management.notes}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
    );
  }

  Widget _buildChip(
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
    final totalC = TextEditingController();
    final healthyC = TextEditingController();
    final sickC = TextEditingController();
    final deadC = TextEditingController();
    final newC = TextEditingController();
    final notesC = TextEditingController();

    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Tambah Manajemen Ayam'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: dc,
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
                controller: totalC,
                decoration: const InputDecoration(labelText: 'Total Ayam'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: healthyC,
                decoration: const InputDecoration(labelText: 'Sehat'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: sickC,
                decoration: const InputDecoration(labelText: 'Sakit'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: deadC,
                decoration: const InputDecoration(labelText: 'Mati'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: newC,
                decoration: const InputDecoration(labelText: 'Baru'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: notesC,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final management = ChickenManagement(
                id: 0,
                userId: 0,
                date: DateTime.parse(dateController.text),
                totalChickens: int.parse(totalC.text),
                healthyChickens: int.parse(healthyC.text),
                sickChickens: int.tryParse(sickC.text) ?? 0,
                deadChickens: int.tryParse(deadC.text) ?? 0,
                newChickens: int.tryParse(newC.text) ?? 0,
                notes: notesC.text.isEmpty ? null : notesC.text,
                createdAt: DateTime.now(),
              );
              final success = await ref
                  .read(chickenManagementProvider.notifier)
                  .createManagement(management);
              if (dc.mounted) {
                Navigator.pop(dc);
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

  void _showEditDialog(BuildContext context, WidgetRef ref,
      ChickenManagement management) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(management.date));
    final totalC =
        TextEditingController(text: management.totalChickens.toString());
    final healthyC =
        TextEditingController(text: management.healthyChickens.toString());
    final sickC =
        TextEditingController(text: management.sickChickens.toString());
    final deadC =
        TextEditingController(text: management.deadChickens.toString());
    final newC =
        TextEditingController(text: management.newChickens.toString());
    final notesC = TextEditingController(text: management.notes ?? '');

    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Edit Manajemen Ayam'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: dc,
                    initialDate: management.date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(date);
                  }
                }),
            const SizedBox(height: 8),
            TextField(
                controller: totalC,
                decoration: const InputDecoration(labelText: 'Total Ayam'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: healthyC,
                decoration: const InputDecoration(labelText: 'Sehat'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: sickC,
                decoration: const InputDecoration(labelText: 'Sakit'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: deadC,
                decoration: const InputDecoration(labelText: 'Mati'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: newC,
                decoration: const InputDecoration(labelText: 'Baru'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(
                controller: notesC,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final updated = ChickenManagement(
                id: management.id,
                userId: management.userId,
                date: DateTime.parse(dateController.text),
                totalChickens: int.parse(totalC.text),
                healthyChickens: int.parse(healthyC.text),
                sickChickens: int.tryParse(sickC.text) ?? 0,
                deadChickens: int.tryParse(deadC.text) ?? 0,
                newChickens: int.tryParse(newC.text) ?? 0,
                notes: notesC.text.isEmpty ? null : notesC.text,
                createdAt: management.createdAt,
              );
              final success = await ref
                  .read(chickenManagementProvider.notifier)
                  .updateManagement(management.id, updated);
              if (dc.mounted) {
                Navigator.pop(dc);
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref,
      ChickenManagement management) {
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(chickenManagementProvider.notifier)
                  .deleteManagement(management.id);
              if (dc.mounted) {
                Navigator.pop(dc);
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
