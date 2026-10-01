class EggProduction {
  final int id;
  final int userId;
  final DateTime date;
  final int totalEggs;
  final int goodEggs;
  final int badEggs;
  final double? weightAvg;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EggProduction({
    required this.id,
    required this.userId,
    required this.date,
    required this.totalEggs,
    required this.goodEggs,
    required this.badEggs,
    this.weightAvg,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory EggProduction.fromJson(Map<String, dynamic> json) {
    return EggProduction(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      totalEggs: json['total_eggs'],
      goodEggs: json['good_eggs'],
      badEggs: json['bad_eggs'],
      weightAvg: json['weight_avg']?.toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'total_eggs': totalEggs,
      'good_eggs': goodEggs,
      'bad_eggs': badEggs,
      'weight_avg': weightAvg,
      'notes': notes,
    };
  }
}
