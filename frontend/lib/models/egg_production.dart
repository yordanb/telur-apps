/// Rincian telur per ekor ayam dalam satu catatan produksi.
class ProductionDetail {
  final int? id;
  final int chickenId;
  final int eggs;
  final String? chickenCode;
  final String? chickenName;

  ProductionDetail({
    this.id,
    required this.chickenId,
    required this.eggs,
    this.chickenCode,
    this.chickenName,
  });

  String get label {
    final code = chickenCode ?? 'ID $chickenId';
    return '$code ×$eggs';
  }

  factory ProductionDetail.fromJson(Map<String, dynamic> json) {
    return ProductionDetail(
      id: json['id'],
      chickenId: json['chicken_id'],
      eggs: json['eggs'],
      chickenCode: json['chicken_code'],
      chickenName: json['chicken_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chicken_id': chickenId,
      'eggs': eggs,
    };
  }
}

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
  final List<ProductionDetail> details;

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
    this.details = const [],
  });

  factory EggProduction.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'] as List?;
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
      details: rawDetails == null
          ? const []
          : rawDetails.map((d) => ProductionDetail.fromJson(d)).toList(),
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
      'details': details.map((d) => d.toJson()).toList(),
    };
  }
}
