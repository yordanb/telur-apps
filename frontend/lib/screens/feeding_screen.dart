import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/feeding_provider.dart';
import '../providers/auth_provider.dart';
import '../models/feeding.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';
import '../widgets/responsive.dart';

class FeedingScreen extends ConsumerWidget {
  const FeedingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedingProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemberian Pakan'),
      ),
      body: Column(
        children: [
          _StockStrip(),
          Expanded(child: _buildBody(context, ref, state)),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, FeedingState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.feedings.isEmpty) {
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
                  ref.read(feedingProvider.notifier).fetchFeedings(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.feedings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada pemberian pakan'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(feedingProvider.notifier).fetchFeedings(),
      child: ListView.builder(
        padding: ResponsiveInsets.all(context, 16),
        itemCount: state.feedings.length,
        itemBuilder: (context, index) {
          final feeding = state.feedings[index];
          return _buildCard(context, ref, feeding);
        },
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, WidgetRef ref, Feeding feeding) {
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
                      DateFormat('dd MMMM yyyy').format(feeding.date),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (SyncService.isTempId(feeding.id)) ...[
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
                            Text('Hapus',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(context, ref, feeding);
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, ref, feeding);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    feeding.feedType,
                    style: const TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${feeding.quantityKg} kg',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                ),
              ],
            ),
            if (feeding.notes != null &&
                feeding.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${feeding.notes}',
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

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final stock = ref.read(feedingProvider).stock;
    final types = stock.keys.toList()..sort();
    String? selectedType = types.isNotEmpty ? types.first : null;
    final customTypeController = TextEditingController();
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    String currentType() => selectedType ?? customTypeController.text.trim();
    double availableFor(String type) => stock[type] ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final type = currentType();
            final qty = double.tryParse(quantityController.text);
            if (type.isEmpty) {
              setDialogState(
                  () => errorText = 'Jenis pakan tidak boleh kosong');
              return;
            }
            if (qty == null || qty <= 0) {
              setDialogState(() =>
                  errorText = 'Jumlah harus berupa angka lebih dari 0');
              return;
            }
            final available = availableFor(type);
            // Stok diketahui (online & ada pembelian) → batasi di depan.
            // Jika stok belum diketahui (offline), antrekan; server validasi.
            if (stock.containsKey(type) && qty - available > 1e-9) {
              setDialogState(() => errorText =
                  'Stok $type tidak cukup (sisa $available kg)');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final feeding = Feeding(
              id: 0,
              userId: 0,
              date: DateTime.parse(dateController.text),
              feedType: type,
              quantityKg: qty,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: DateTime.now(),
            );

            final result = await ref
                .read(feedingProvider.notifier)
                .createFeeding(feeding);

            if (dialogContext.mounted) {
              if (result != SaveResult.failed) {
                Navigator.pop(dialogContext);
                final (message, color) = result == SaveResult.synced
                    ? ('Pemberian pakan tersimpan', Colors.green)
                    : (
                        'Disimpan offline — otomatis dikirim saat online',
                        Colors.orange
                      );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: color),
                );
              } else {
                setDialogState(() {
                  errorText =
                      'Gagal menyimpan (kemungkinan stok berubah). Muat ulang lalu coba lagi.';
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Beri Pakan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                        labelText: 'Tanggal (YYYY-MM-DD)'),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        dateController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (types.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                          labelText: 'Jenis pakan'),
                      items: types
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                    '$t (sisa ${stock[t]} kg)'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedType = value);
                      },
                    )
                  else
                    TextField(
                      controller: customTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Jenis pakan',
                        hintText:
                            'Belum ada pembelian — catat di Biaya dulu',
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                        labelText: 'Jumlah (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration:
                        const InputDecoration(labelText: 'Catatan'),
                    maxLines: 2,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                            color: Colors.red[800], fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, Feeding feeding) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(feeding.date));
    final stock = ref.read(feedingProvider).stock;
    final types = stock.keys.toList()..sort();
    if (!types.contains(feeding.feedType)) types.add(feeding.feedType);
    String? selectedType = feeding.feedType;
    final quantityController =
        TextEditingController(text: feeding.quantityKg.toString());
    final notesController = TextEditingController(text: feeding.notes ?? '');
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final type = selectedType ?? '';
            final qty = double.tryParse(quantityController.text);
            if (type.isEmpty) {
              setDialogState(
                  () => errorText = 'Jenis pakan tidak boleh kosong');
              return;
            }
            if (qty == null || qty <= 0) {
              setDialogState(() =>
                  errorText = 'Jumlah harus berupa angka lebih dari 0');
              return;
            }
            // Jatah sendiri dikembalikan saat hitung (khusus tipe sama).
            var available = stock[type] ?? 0;
            if (type == feeding.feedType) {
              available += feeding.quantityKg;
            }
            if (stock.containsKey(type) && qty - available > 1e-9) {
              setDialogState(() => errorText =
                  'Stok $type tidak cukup (sisa $available kg)');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final updated = Feeding(
              id: feeding.id,
              userId: feeding.userId,
              date: DateTime.parse(dateController.text),
              feedType: type,
              quantityKg: qty,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: feeding.createdAt,
            );

            final success = await ref
                .read(feedingProvider.notifier)
                .updateFeeding(feeding.id, updated);

            if (dialogContext.mounted) {
              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(SyncService.isTempId(feeding.id)
                        ? 'Perubahan disimpan offline'
                        : 'Pemberian berhasil diperbarui'),
                    backgroundColor: SyncService.isTempId(feeding.id)
                        ? Colors.orange
                        : Colors.green,
                  ),
                );
              } else {
                setDialogState(() {
                  errorText =
                      'Gagal menyimpan. Periksa koneksi lalu coba lagi.';
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Edit Pemberian'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                        labelText: 'Tanggal (YYYY-MM-DD)'),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: feeding.date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        dateController.text =
                            DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration:
                        const InputDecoration(labelText: 'Jenis pakan'),
                    items: types
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                        labelText: 'Jumlah (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration:
                        const InputDecoration(labelText: 'Catatan'),
                    maxLines: 2,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                            color: Colors.red[800], fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Feeding feeding) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pemberian'),
        content: Text(
            'Hapus pemberian ${feeding.feedType} ${feeding.quantityKg} kg? Stok akan bertambah kembali.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ref
                  .read(feedingProvider.notifier)
                  .deleteFeeding(feeding.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Pemberian berhasil dihapus'
                        : 'Gagal menghapus pemberian'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

/// Strip sisa stok per jenis pakan di atas daftar.
class _StockStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(feedingProvider.select((s) => s.stock));
    final types = stock.keys.toList()..sort();

    if (types.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Belum ada stok. Catat pembelian pakan di Biaya (kategori Pakan).',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = types[i];
          final sisa = stock[type] ?? 0;
          final low = sisa <= 0;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (low ? Colors.red : Colors.brown).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      (low ? Colors.red : Colors.brown).withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'Sisa $sisa kg',
                  style: TextStyle(
                    color: low ? Colors.red : Colors.brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
