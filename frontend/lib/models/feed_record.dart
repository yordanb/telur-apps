class FeedRecord {
  final int id;
  final int userId;
  final DateTime date;
  final String feedType;
  final double quantityKg;
  final double costPerKg;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FeedRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.feedType,
    required this.quantityKg,
    required this.costPerKg,
    required this.totalCost,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory FeedRecord.fromJson(Map<String, dynamic> json) {
    return FeedRecord(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      feedType: json['feed_type'],
      quantityKg: json['quantity_kg'].toDouble(),
      costPerKg: json['cost_per_kg'].toDouble(),
      totalCost: json['total_cost'].toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'feed_type': feedType,
      'quantity_kg': quantityKg,
      'cost_per_kg': costPerKg,
      'total_cost': totalCost,
      'notes': notes,
    };
  }
}
