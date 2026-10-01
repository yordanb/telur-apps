class CostRecord {
  final int id;
  final int userId;
  final DateTime date;
  final String category;
  final String description;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CostRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
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
      description: json['description'],
      amount: json['amount'].toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
      'amount': amount,
      'notes': notes,
    };
  }
}
