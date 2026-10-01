class ChickenManagement {
  final int id;
  final int userId;
  final DateTime date;
  final int totalChickens;
  final int healthyChickens;
  final int sickChickens;
  final int deadChickens;
  final int newChickens;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChickenManagement({
    required this.id,
    required this.userId,
    required this.date,
    required this.totalChickens,
    required this.healthyChickens,
    required this.sickChickens,
    required this.deadChickens,
    required this.newChickens,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChickenManagement.fromJson(Map<String, dynamic> json) {
    return ChickenManagement(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      totalChickens: json['total_chickens'],
      healthyChickens: json['healthy_chickens'],
      sickChickens: json['sick_chickens'],
      deadChickens: json['dead_chickens'],
      newChickens: json['new_chickens'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'total_chickens': totalChickens,
      'healthy_chickens': healthyChickens,
      'sick_chickens': sickChickens,
      'dead_chickens': deadChickens,
      'new_chickens': newChickens,
      'notes': notes,
    };
  }
}
