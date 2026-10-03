class CashTransaction {
  final int id;
  final int userId;
  final DateTime date;
  final String direction; // 'masuk' | 'keluar'
  final String category;
  final String description;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CashTransaction({
    required this.id,
    required this.userId,
    required this.date,
    required this.direction,
    required this.category,
    required this.description,
    required this.amount,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => direction == 'masuk';

  factory CashTransaction.fromJson(Map<String, dynamic> json) {
    return CashTransaction(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      direction: json['direction'] as String,
      category: json['category'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
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
      'direction': direction,
      'category': category,
      'description': description,
      'amount': amount,
      'notes': notes,
    };
  }
}
