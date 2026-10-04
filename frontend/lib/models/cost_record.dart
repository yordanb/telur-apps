class CostRecord {
  final int id;
  final int userId;
  final DateTime date;
  final String category;
  final String? subcategory;
  final String description;
  final double amount;
  // Khusus pembelian pakan (category == 'pakan')
  final String? feedType;
  final double? quantityKg;
  final double? pricePerKg;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CostRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.category,
    this.subcategory,
    required this.description,
    required this.amount,
    this.feedType,
    this.quantityKg,
    this.pricePerKg,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory CostRecord.fromJson(Map<String, dynamic> json) {
    return CostRecord(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      category: json['category'],
      subcategory: json['subcategory'],
      description: json['description'],
      amount: json['amount'].toDouble(),
      feedType: json['feed_type'],
      quantityKg: json['quantity_kg']?.toDouble(),
      pricePerKg: json['price_per_kg']?.toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'amount': amount,
      'feed_type': feedType,
      'quantity_kg': quantityKg,
      'price_per_kg': pricePerKg,
      'notes': notes,
    };
  }

  /// Label Indonesia untuk kategori (nilai tersimpan tetap bahasa Inggris
  /// agar kompatibel dengan data lama).
  static String categoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'pakan':
        return 'Pakan';
      case 'obat':
        return 'Obat-obatan';
      case 'operasional':
        return 'Operasional';
      default:
        return 'Lainnya';
    }
  }

  /// Subkategori operasional: perbaikan / perawatan / pembuatan kandang.
  static const List<String> operationalSubs = [
    'Perbaikan kandang',
    'Perawatan kandang',
    'Pembuatan kandang baru',
  ];
}
