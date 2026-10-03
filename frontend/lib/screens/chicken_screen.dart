import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/chicken_provider.dart';
import '../providers/auth_provider.dart';
import '../models/chicken.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../widgets/offline_chip.dart';

class ChickenScreen extends ConsumerStatefulWidget {
  const ChickenScreen({super.key});

  @override
  ConsumerState<ChickenScreen> createState() => _ChickenScreenState();
}

class _ChickenScreenState extends ConsumerState<ChickenScreen> {
  String _filter = 'semua'; // semua | aktif | sakit | mati | terjual

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chickenProvider);
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));

    final visible = state.chickens
        .where((c) => _filter == 'semua' || c.status == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Ayam'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _FilterChip(
                    label: 'Semua',
                    selected: _filter == 'semua',
                    onTap: () => setState(() => _filter = 'semua')),
                const SizedBox(width: 8),
                for (final s in Chicken.statuses) ...[
                  _FilterChip(
                    label: Chicken.statusLabel(s),
                    selected: _filter == s,
                    onTap: () => setState(() => _filter = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: _buildBody(context, visible)),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, List<Chicken> items) {
    final state = ref.watch(chickenProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.chickens.isEmpty) {
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
                  ref.read(chickenProvider.notifier).fetchChickens(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada ayam terdaftar'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(chickenProvider.notifier).fetchChickens(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildCard(context, items[index]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Chicken chicken) {
    final canEdit =
        ref.watch(authProvider.select((s) => s.user?.canEdit ?? true));
    final photoUrl = ApiService.photoUrl(chicken.photoPath);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.orange.withOpacity(0.15),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              onBackgroundImageError:
                  photoUrl.isNotEmpty ? (_, __) {} : null,
              child: photoUrl.isEmpty
                  ? Text(
                      chicken.code.isNotEmpty
                          ? chicken.code[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 22),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chicken.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (SyncService.isTempId(chicken.id))
                        const OfflineChip(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(chicken.status),
                      if (chicken.breed != null &&
                          chicken.breed!.isNotEmpty)
                        Text(chicken.breed!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  if (chicken.acquiredDate != null)
                    Text(
                      'Masuk: ${DateFormat('dd MMM yyyy').format(chicken.acquiredDate!)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'photo',
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera),
                        SizedBox(width: 8),
                        Text('Foto'),
                      ],
                    ),
                  ),
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
                  if (value == 'photo') {
                    _pickAndUploadPhoto(context, chicken);
                  } else if (value == 'edit') {
                    _showEditDialog(context, chicken);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, chicken);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
      BuildContext context, Chicken chicken) async {
    if (SyncService.isTempId(chicken.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kirim dulu data ayam ini saat online, baru tambahkan foto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil foto (kamera)'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final file =
        await ImagePicker().pickImage(source: source, maxWidth: 1024);
    if (file == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Mengunggah foto...'),
          duration: Duration(seconds: 20)),
    );
    final path = await ref
        .read(chickenProvider.notifier)
        .uploadPhoto(chicken.id, file.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null
              ? 'Foto berhasil disimpan'
              : 'Gagal mengunggah foto. Periksa koneksi.'),
          backgroundColor: path != null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final breedController = TextEditingController();
    final dateController = TextEditingController();
    String status = 'aktif';
    final notesController = TextEditingController();
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (codeController.text.trim().isEmpty) {
              setDialogState(
                  () => errorText = 'Kode/ID ayam tidak boleh kosong');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final chicken = Chicken(
              id: 0,
              userId: 0,
              code: codeController.text.trim(),
              name: nameController.text.trim().isEmpty
                  ? null
                  : nameController.text.trim(),
              breed: breedController.text.trim().isEmpty
                  ? null
                  : breedController.text.trim(),
              acquiredDate: dateController.text.isEmpty
                  ? null
                  : DateTime.parse(dateController.text),
              status: status,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: DateTime.now(),
            );

            final result = await ref
                .read(chickenProvider.notifier)
                .createChicken(chicken);

            if (dialogContext.mounted) {
              if (result != SaveResult.failed) {
                Navigator.pop(dialogContext);
                final (message, color) = result == SaveResult.synced
                    ? ('Ayam berhasil didaftarkan', Colors.green)
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
                      'Gagal menyimpan (kemungkinan kode sudah dipakai).';
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Daftarkan Ayam'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Kode / ID ayam *',
                      hintText: 'cth: AY-001',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama panggilan (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: breedController,
                    decoration: const InputDecoration(
                        labelText: 'Jenis/strain (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                        labelText: 'Tanggal masuk (opsional)'),
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
                    value: status,
                    decoration:
                        const InputDecoration(labelText: 'Status'),
                    items: Chicken.statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(Chicken.statusLabel(s)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => status = value!);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration:
                        const InputDecoration(labelText: 'Catatan'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Foto profil dapat ditambahkan setelah tersimpan '
                    '(menu ⋮ → Foto, butuh online).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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

  void _showEditDialog(BuildContext context, Chicken chicken) {
    final codeController = TextEditingController(text: chicken.code);
    final nameController = TextEditingController(text: chicken.name ?? '');
    final breedController = TextEditingController(text: chicken.breed ?? '');
    final dateController = TextEditingController(
        text: chicken.acquiredDate != null
            ? DateFormat('yyyy-MM-dd').format(chicken.acquiredDate!)
            : '');
    String status = chicken.status;
    final notesController = TextEditingController(text: chicken.notes ?? '');
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (codeController.text.trim().isEmpty) {
              setDialogState(
                  () => errorText = 'Kode/ID ayam tidak boleh kosong');
              return;
            }
            setDialogState(() {
              errorText = null;
              isSaving = true;
            });

            final updated = Chicken(
              id: chicken.id,
              userId: chicken.userId,
              code: codeController.text.trim(),
              name: nameController.text.trim().isEmpty
                  ? null
                  : nameController.text.trim(),
              breed: breedController.text.trim().isEmpty
                  ? null
                  : breedController.text.trim(),
              acquiredDate: dateController.text.isEmpty
                  ? null
                  : DateTime.parse(dateController.text),
              status: status,
              photoPath: chicken.photoPath,
              notes: notesController.text.isEmpty
                  ? null
                  : notesController.text,
              createdAt: chicken.createdAt,
            );

            final success = await ref
                .read(chickenProvider.notifier)
                .updateChicken(chicken.id, updated);

            if (dialogContext.mounted) {
              if (success) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(SyncService.isTempId(chicken.id)
                        ? 'Perubahan disimpan offline'
                        : 'Data ayam berhasil diperbarui'),
                    backgroundColor: SyncService.isTempId(chicken.id)
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
            title: const Text('Edit Ayam'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                        labelText: 'Kode / ID ayam *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama panggilan (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: breedController,
                    decoration: const InputDecoration(
                        labelText: 'Jenis/strain (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                        labelText: 'Tanggal masuk (opsional)'),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate:
                            chicken.acquiredDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          dateController.text =
                              DateFormat('yyyy-MM-dd').format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: Chicken.statuses.contains(status)
                        ? status
                        : 'aktif',
                    decoration:
                        const InputDecoration(labelText: 'Status'),
                    items: Chicken.statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(Chicken.statusLabel(s)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(
                          () => status = value ?? chicken.status);
                    },
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

  void _showDeleteDialog(BuildContext context, Chicken chicken) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Ayam'),
        content: Text(
            'Hapus ${chicken.displayName} dari register? Rincian produksinya ikut terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ref
                  .read(chickenProvider.notifier)
                  .deleteChicken(chicken.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Ayam berhasil dihapus'
                        : 'Gagal menghapus ayam'),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'aktif' => Colors.green,
      'sakit' => Colors.orange,
      'mati' => Colors.red,
      'terjual' => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        Chicken.statusLabel(status),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
