import 'package:flutter/material.dart';
import '../widgets/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/feed_record_provider.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';
import '../providers/auth_provider.dart';
import '../models/feed_record.dart';

class FeedRecordScreen extends ConsumerWidget {
  const FeedRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedRecordProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencatatan Pakan'),
      ),
      body: _buildBody(context, ref, state),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, FeedRecordState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(feedRecordProvider.notifier).fetchRecords(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grain, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada data pakan'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(feedRecordProvider.notifier).fetchRecords(),
      child: ListView.builder(
        padding: ResponsiveInsets.all(context, 16),
        itemCount: state.records.length,
        itemBuilder: (context, index) {
          final record = state.records[index];
          return _buildRecordCard(context, ref, record);
        },
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, WidgetRef ref, FeedRecord record) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: ResponsiveInsets.all(context, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy').format(record.date),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (SyncService.isTempId(record.id)) ...[
                      const SizedBox(width: 8),
                      const OfflineChip(),
                    ],
                  ],
                ),
                if (canEdit)
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
                        _showEditDialog(context, ref, record);
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, ref, record);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.grain,
                  label: 'Jenis Pakan',
                  value: record.feedType,
                  color: Colors.brown,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.scale,
                  label: 'Jumlah',
                  value: '${record.quantityKg} kg',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.attach_money,
                  label: 'Harga/kg',
                  value: 'Rp ${formatter.format(record.costPerKg)}',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Biaya:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${formatter.format(record.totalCost)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${record.notes}',
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
              textAlign: TextAlign.center,
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final feedTypeController = TextEditingController();
    final quantityController = TextEditingController();
    final costPerKgController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Pakan'),
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
                    context: dialogContext,
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
                controller: feedTypeController,
                decoration: const InputDecoration(labelText: 'Jenis Pakan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Jumlah (kg)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costPerKgController,
                decoration: const InputDecoration(labelText: 'Harga per kg (Rp)'),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.parse(quantityController.text);
              final costPerKg = double.parse(costPerKgController.text);

              final record = FeedRecord(
                id: 0,
                userId: 0,
                date: DateTime.parse(dateController.text),
                feedType: feedTypeController.text,
                quantityKg: quantity,
                costPerKg: costPerKg,
                totalCost: quantity * costPerKg,
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: DateTime.now(),
              );

              final result = await ref.read(feedRecordProvider.notifier).createRecord(record);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                final (message, color) = switch (result) {
                  SaveResult.synced => (
                      'Data berhasil ditambahkan',
                      Colors.green
                    ),
                  SaveResult.queued => (
                      'Disimpan offline — otomatis dikirim saat online',
                      Colors.orange
                    ),
                  SaveResult.failed => (
                      'Gagal menambahkan data',
                      Colors.red
                    ),
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: color,
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

  void _showEditDialog(BuildContext context, WidgetRef ref, FeedRecord record) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(record.date));
    final feedTypeController = TextEditingController(text: record.feedType);
    final quantityController = TextEditingController(text: record.quantityKg.toString());
    final costPerKgController = TextEditingController(text: record.costPerKg.toString());
    final notesController = TextEditingController(text: record.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Pakan'),
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
                    context: dialogContext,
                    initialDate: record.date,
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
                controller: feedTypeController,
                decoration: const InputDecoration(labelText: 'Jenis Pakan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Jumlah (kg)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costPerKgController,
                decoration: const InputDecoration(labelText: 'Harga per kg (Rp)'),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.parse(quantityController.text);
              final costPerKg = double.parse(costPerKgController.text);

              final updatedRecord = FeedRecord(
                id: record.id,
                userId: record.userId,
                date: DateTime.parse(dateController.text),
                feedType: feedTypeController.text,
                quantityKg: quantity,
                costPerKg: costPerKg,
                totalCost: quantity * costPerKg,
                notes: notesController.text.isEmpty ? null : notesController.text,
                createdAt: record.createdAt,
              );

              final success = await ref.read(feedRecordProvider.notifier).updateRecord(record.id, updatedRecord);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, FeedRecord record) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(feedRecordProvider.notifier).deleteRecord(record.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
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
