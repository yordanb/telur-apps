import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/cost_record_provider.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';
import '../providers/auth_provider.dart';
import '../models/cost_record.dart';

class CostRecordScreen extends ConsumerWidget {
  const CostRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(costRecordProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencatatan Biaya'),
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

  Widget _buildBody(BuildContext context, WidgetRef ref, CostRecordState state) {
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
              onPressed: () => ref.read(costRecordProvider.notifier).fetchRecords(),
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
            Icon(Icons.attach_money, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada data biaya'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(costRecordProvider.notifier).fetchRecords(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.records.length,
        itemBuilder: (context, index) {
          final record = state.records[index];
          return _buildRecordCard(context, ref, record);
        },
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, WidgetRef ref, CostRecord record) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

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
                _buildCategoryChip(record.category),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Rp ${formatter.format(record.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.description,
              style: Theme.of(context).textTheme.bodyMedium,
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

  Widget _buildCategoryChip(String category) {
    Color color;
    IconData icon;

    switch (category.toLowerCase()) {
      case 'pakan':
        color = Colors.brown;
        icon = Icons.grain;
        break;
      case 'obat':
        color = Colors.green;
        icon = Icons.medical_services;
        break;
      case 'operasional':
        color = Colors.blue;
        icon = Icons.settings;
        break;
      default:
        color = Colors.grey;
        icon = Icons.category;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            category,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String selectedCategory = 'pakan';
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Tambah Biaya'),
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
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'pakan', child: Text('Pakan')),
                    DropdownMenuItem(value: 'obat', child: Text('Obat')),
                    DropdownMenuItem(value: 'operasional', child: Text('Operasional')),
                    DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
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
                final record = CostRecord(
                  id: 0,
                  userId: 0,
                  date: DateTime.parse(dateController.text),
                  category: selectedCategory,
                  description: descriptionController.text,
                  amount: double.parse(amountController.text),
                  notes: notesController.text.isEmpty ? null : notesController.text,
                  createdAt: DateTime.now(),
                );

                final result = await ref.read(costRecordProvider.notifier).createRecord(record);

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
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, CostRecord record) {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(record.date));
    String selectedCategory = record.category;
    final descriptionController = TextEditingController(text: record.description);
    final amountController = TextEditingController(text: record.amount.toString());
    final notesController = TextEditingController(text: record.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Biaya'),
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
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'pakan', child: Text('Pakan')),
                    DropdownMenuItem(value: 'obat', child: Text('Obat')),
                    DropdownMenuItem(value: 'operasional', child: Text('Operasional')),
                    DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
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
                final updatedRecord = CostRecord(
                  id: record.id,
                  userId: record.userId,
                  date: DateTime.parse(dateController.text),
                  category: selectedCategory,
                  description: descriptionController.text,
                  amount: double.parse(amountController.text),
                  notes: notesController.text.isEmpty ? null : notesController.text,
                  createdAt: record.createdAt,
                );

                final success = await ref.read(costRecordProvider.notifier).updateRecord(record.id, updatedRecord);

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
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, CostRecord record) {
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
              final success = await ref.read(costRecordProvider.notifier).deleteRecord(record.id);
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
