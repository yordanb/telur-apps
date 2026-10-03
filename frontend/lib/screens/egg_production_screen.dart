import 'package:flutter/material.dart';
import '../widgets/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/egg_production_provider.dart';
import '../providers/chicken_provider.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';
import '../providers/auth_provider.dart';
import '../models/egg_production.dart';
import '../models/chicken.dart';

class EggProductionScreen extends ConsumerWidget {
  const EggProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eggProductionProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produksi Telur'),
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
        padding: ResponsiveInsets.all(context, 16),
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
                      DateFormat('dd MMMM yyyy').format(production.date),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (SyncService.isTempId(production.id)) ...[
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
            if (production.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in production.details)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        d.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
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
    final chickens =
        ref.read(chickenProvider).chickens.where((c) => c.isActive).toList();
    var details = <ProductionDetail>[];

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
            _DetailsEditor(
              chickens: chickens,
              initial: const [],
              totalEggsController: totalEggsController,
              goodEggsController: goodEggsController,
              onChanged: (list) => details = list,
            ),
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
                details: details,
              );
              final result = await ref
                  .read(eggProductionProvider.notifier)
                  .createProduction(production);
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(message),
                  backgroundColor: color,
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
    final chickens =
        ref.read(chickenProvider).chickens.where((c) => c.isActive).toList();
    // Ayam non-aktif yang sudah ada di rincian tetap ditampilkan.
    for (final d in production.details) {
      if (!chickens.any((c) => c.id == d.chickenId)) {
        final all = ref.read(chickenProvider).chickens;
        final found = all.where((c) => c.id == d.chickenId).toList();
        if (found.isNotEmpty) chickens.add(found.first);
      }
    }
    var details = List<ProductionDetail>.from(production.details);

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
            const SizedBox(height: 8),
            _DetailsEditor(
              chickens: chickens,
              initial: production.details,
              totalEggsController: totalEggsController,
              goodEggsController: goodEggsController,
              onChanged: (list) => details = list,
            ),
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
                details: details,
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

/// Editor rincian telur per ekor: daftar dinamis (ayam + jumlah butir).
/// Mengelola state baris sendiri; perubahan valid dilaporkan via [onChanged].
/// Tombol "Samakan total" mengisi total & telur baik dari jumlah rincian.
class _DetailsEditor extends StatefulWidget {
  const _DetailsEditor({
    required this.chickens,
    required this.initial,
    required this.totalEggsController,
    required this.goodEggsController,
    required this.onChanged,
  });

  final List<Chicken> chickens;
  final List<ProductionDetail> initial;
  final TextEditingController totalEggsController;
  final TextEditingController goodEggsController;
  final ValueChanged<List<ProductionDetail>> onChanged;

  @override
  State<_DetailsEditor> createState() => _DetailsEditorState();
}

class _DetailRow {
  int? chickenId;
  final TextEditingController eggsController;

  _DetailRow({this.chickenId, int eggs = 0})
      : eggsController =
            TextEditingController(text: eggs > 0 ? eggs.toString() : '');
}

class _DetailsEditorState extends State<_DetailsEditor> {
  late List<_DetailRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial
        .map((d) =>
            _DetailRow(chickenId: d.chickenId, eggs: d.eggs))
        .toList();
    if (_rows.isEmpty) _rows.add(_DetailRow());
  }

  void _emit() {
    widget.onChanged(_rows
        .where((r) =>
            r.chickenId != null &&
            (int.tryParse(r.eggsController.text) ?? 0) > 0)
        .map((r) => ProductionDetail(
              chickenId: r.chickenId!,
              eggs: int.parse(r.eggsController.text),
            ))
        .toList());
  }

  int get _sum => _rows.fold(
      0, (sum, r) => sum + (int.tryParse(r.eggsController.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    if (widget.chickens.isEmpty) {
      return const Text(
        'Rincian per ayam: daftarkan ayam dulu di Register Ayam.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final selectedIds =
        _rows.map((r) => r.chickenId).whereType<int>().toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rincian per ayam (opsional)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        for (int i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    value: _rows[i].chickenId,
                    decoration: const InputDecoration(
                      labelText: 'ID ayam',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: widget.chickens
                        .where((c) =>
                            !selectedIds.contains(c.id) ||
                            c.id == _rows[i].chickenId)
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.code,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _rows[i].chickenId = v);
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rows[i].eggsController,
                    decoration: const InputDecoration(
                      labelText: 'Butir',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      _emit();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: _rows.length > 1
                      ? () {
                          setState(() => _rows.removeAt(i));
                          _emit();
                        }
                      : null,
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() => _rows.add(_DetailRow()));
                _emit();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah ayam'),
            ),
            const Spacer(),
            if (_sum > 0)
              TextButton(
                onPressed: () {
                  widget.totalEggsController.text = _sum.toString();
                  widget.goodEggsController.text = _sum.toString();
                },
                child: Text('Samakan total ($_sum)'),
              ),
          ],
        ),
      ],
    );
  }
}
