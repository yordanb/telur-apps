/// Pemberian pakan ke ayam (konsumsi, mengurangi stok).
class Feeding {
  final int id;
  final int userId;
  final DateTime date;
  final String feedType;
  final double quantityKg;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Feeding({
    required this.id,
    required this.userId,
    required this.date,
    required this.feedType,
    required this.quantityKg,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Feeding.fromJson(Map<String, dynamic> json) {
    return Feeding(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      feedType: json['feed_type'],
      quantityKg: (json['quantity_kg'] as num).toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'feed_type': feedType,
      'quantity_kg': quantityKg,
      'notes': notes,
    };
  }
}
