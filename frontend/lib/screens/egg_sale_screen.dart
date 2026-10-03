import 'package:flutter/material.dart';
import '../widgets/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/egg_sale_provider.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';
import '../providers/auth_provider.dart';
import '../models/egg_sale.dart';

class EggSaleScreen extends ConsumerWidget {
  const EggSaleScreen({super.key});

  static const saleColor = Colors.teal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eggSaleProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    final totalRevenue =
        state.sales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final formatter = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjualan Telur'),
      ),
      body: Column(
        children: [
          if (state.sales.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: ResponsiveInsets.all(context, 16),
              decoration: BoxDecoration(
                color: saleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: saleColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: saleColor, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pendapatan',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Rp ${formatter.format(totalRevenue)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: saleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  Widget _buildBody(BuildContext context, WidgetRef ref, EggSaleState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.sales.isEmpty) {
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
                  ref.read(eggSaleProvider.notifier).fetchSales(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada data penjualan'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(eggSaleProvider.notifier).fetchSales(),
      child: ListView.builder(
        padding: ResponsiveInsets.all(context, 16),
        itemCount: state.sales.length,
        itemBuilder: (context, index) {
          final sale = state.sales[index];
          return _buildSaleCard(context, ref, sale);
        },
      ),
    );
  }

  Widget _buildSaleCard(BuildContext context, WidgetRef ref, EggSale sale) {
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
                      DateFormat('dd MMMM yyyy').format(sale.date),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (SyncService.isTempId(sale.id)) ...[
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
                        _showEditDialog(context, ref, sale);
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, ref, sale);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildUnitChip(sale.unit),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${sale.quantityLabel} × Rp ${formatter.format(sale.pricePerUnit)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: saleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Rp ${formatter.format(sale.totalPrice)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: saleColor,
                  fontSize: 16,
                ),
              ),
            ),
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${sale.notes}',
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

  Widget _buildUnitChip(String unit) {
    final isKg = unit == 'kg';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isKg ? Colors.blue : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isKg ? Icons.scale : Icons.egg,
              size: 16, color: isKg ? Colors.blue : Colors.orange),
          const SizedBox(width: 4),
          Text(
            isKg ? 'Per Kg' : 'Per Butir',
            style: TextStyle(
              color: isKg ? Colors.blue : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String selectedUnit = 'butir';
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final notesController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          double previewTotal() {
            final q = double.tryParse(quantityController.text) ?? 0;
            final p = double.tryParse(priceController.text) ?? 0;
            return q * p;
          }

          final formatter = NumberFormat('#,###', 'id_ID');

          Future<void> submit() async {
            final quantity = double.tryParse(quantityController.text);
            final price = double.tryParse(priceController.text);
            if (quantity == null || quantity <= 0) {
              setDialogState(() =>
                  errorText = 'Jumlah harus berupa angka lebih dari 0');
              return;
            }
            if (price == null || price < 0) {
              setDialogState(() =>
                  errorText = 'Harga harus berupa angka (tidak negatif)');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final sale = EggSale(
              id: 0,
              userId: 0,
              date: DateTime.parse(dateController.text),
              unit: selectedUnit,
              quantity: quantity,
              pricePerUnit: price,
              totalPrice: quantity * price,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: DateTime.now(),
            );

            final result = await ref
                .read(eggSaleProvider.notifier)
                .createSale(sale);

            if (dialogContext.mounted) {
              if (result != SaveResult.failed) {
                Navigator.pop(dialogContext);
                final (message, color) = result == SaveResult.synced
                    ? (
                        'Penjualan berhasil ditambahkan',
                        Colors.green
                      )
                    : (
                        'Disimpan offline — otomatis dikirim saat online',
                        Colors.orange
                      );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: color,
                  ),
                );
              } else {
                setDialogState(() {
                  errorText = 'Gagal menyimpan. Periksa koneksi lalu coba lagi.';
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Tambah Penjualan'),
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
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration:
                        const InputDecoration(labelText: 'Satuan jual'),
                    items: const [
                      DropdownMenuItem(
                          value: 'butir', child: Text('Per Butir')),
                      DropdownMenuItem(value: 'kg', child: Text('Per Kg')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedUnit = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                        labelText: selectedUnit == 'kg'
                            ? 'Jumlah (kg)'
                            : 'Jumlah (butir)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                        labelText: selectedUnit == 'kg'
                            ? 'Harga per kg (Rp)'
                            : 'Harga per butir (Rp)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: saleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: Rp ${formatter.format(previewTotal())}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saleColor,
                        fontSize: 16,
                      ),
                    ),
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
                        style:
                            TextStyle(color: Colors.red[800], fontSize: 13),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, EggSale sale) {
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(sale.date));
    String selectedUnit = sale.unit;
    final quantityController =
        TextEditingController(text: sale.quantity.toString());
    final priceController =
        TextEditingController(text: sale.pricePerUnit.toString());
    final notesController = TextEditingController(text: sale.notes ?? '');
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          double previewTotal() {
            final q = double.tryParse(quantityController.text) ?? 0;
            final p = double.tryParse(priceController.text) ?? 0;
            return q * p;
          }

          final formatter = NumberFormat('#,###', 'id_ID');

          Future<void> submit() async {
            final quantity = double.tryParse(quantityController.text);
            final price = double.tryParse(priceController.text);
            if (quantity == null || quantity <= 0) {
              setDialogState(() =>
                  errorText = 'Jumlah harus berupa angka lebih dari 0');
              return;
            }
            if (price == null || price < 0) {
              setDialogState(() =>
                  errorText = 'Harga harus berupa angka (tidak negatif)');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final updated = EggSale(
              id: sale.id,
              userId: sale.userId,
              date: DateTime.parse(dateController.text),
              unit: selectedUnit,
              quantity: quantity,
              pricePerUnit: price,
              totalPrice: quantity * price,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: sale.createdAt,
            );

            final success = await ref
                .read(eggSaleProvider.notifier)
                .updateSale(sale.id, updated);

            if (dialogContext.mounted) {
              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(SyncService.isTempId(sale.id)
                        ? 'Perubahan disimpan offline'
                        : 'Penjualan berhasil diperbarui'),
                    backgroundColor: SyncService.isTempId(sale.id)
                        ? Colors.orange
                        : Colors.green,
                  ),
                );
              } else {
                setDialogState(() {
                  errorText = 'Gagal menyimpan. Periksa koneksi lalu coba lagi.';
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Edit Penjualan'),
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
                        initialDate: sale.date,
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
                    value: selectedUnit,
                    decoration:
                        const InputDecoration(labelText: 'Satuan jual'),
                    items: const [
                      DropdownMenuItem(
                          value: 'butir', child: Text('Per Butir')),
                      DropdownMenuItem(value: 'kg', child: Text('Per Kg')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedUnit = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                        labelText: selectedUnit == 'kg'
                            ? 'Jumlah (kg)'
                            : 'Jumlah (butir)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                        labelText: selectedUnit == 'kg'
                            ? 'Harga per kg (Rp)'
                            : 'Harga per butir (Rp)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: saleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: Rp ${formatter.format(previewTotal())}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saleColor,
                        fontSize: 16,
                      ),
                    ),
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
                        style:
                            TextStyle(color: Colors.red[800], fontSize: 13),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, EggSale sale) {
    final formatter = NumberFormat('#,###', 'id_ID');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Penjualan'),
        content: Text(
            'Hapus penjualan ${sale.quantityLabel} (Rp ${formatter.format(sale.totalPrice)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ref
                  .read(eggSaleProvider.notifier)
                  .deleteSale(sale.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Penjualan berhasil dihapus'
                        : 'Gagal menghapus penjualan'),
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
