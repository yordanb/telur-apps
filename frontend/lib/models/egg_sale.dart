class EggSale {
  final int id;
  final int userId;
  final DateTime date;
  final String unit; // 'butir' | 'kg'
  final double quantity;
  final double pricePerUnit;
  final double totalPrice;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EggSale({
    required this.id,
    required this.userId,
    required this.date,
    required this.unit,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  static double _toDouble(dynamic v) => (v as num).toDouble();

  factory EggSale.fromJson(Map<String, dynamic> json) {
    return EggSale(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      unit: json['unit'] as String,
      quantity: _toDouble(json['quantity']),
      pricePerUnit: _toDouble(json['price_per_unit']),
      totalPrice: _toDouble(json['total_price']),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Body create/update — total_price dihitung server.
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'unit': unit,
      'quantity': quantity,
      'price_per_unit': pricePerUnit,
      'notes': notes,
    };
  }

  String get quantityLabel =>
      unit == 'kg' ? '${quantity.toStringAsFixed(1)} kg' : '${quantity.toInt()} butir';

  String get priceLabel =>
      unit == 'kg' ? 'Rp $pricePerUnit/kg' : 'Rp $pricePerUnit/butir';
}
