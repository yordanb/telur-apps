class Chicken {
  final int id;
  final int userId;
  final String code;
  final String? name;
  final String? breed;
  final DateTime? acquiredDate;
  final String status; // aktif | sakit | mati | terjual
  final String? photoPath; // relatif, mis. 'uploads/abc.jpg'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Chicken({
    required this.id,
    required this.userId,
    required this.code,
    this.name,
    this.breed,
    this.acquiredDate,
    required this.status,
    this.photoPath,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'aktif';

  String get displayName =>
      (name != null && name!.isNotEmpty) ? '$code • $name' : code;

  factory Chicken.fromJson(Map<String, dynamic> json) {
    return Chicken(
      id: json['id'],
      userId: json['user_id'],
      code: json['code'],
      name: json['name'],
      breed: json['breed'],
      acquiredDate: json['acquired_date'] != null
          ? DateTime.parse(json['acquired_date'])
          : null,
      status: json['status'] ?? 'aktif',
      photoPath: json['photo_path'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'breed': breed,
      'acquired_date': acquiredDate?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  static const List<String> statuses = ['aktif', 'sakit', 'mati', 'terjual'];

  static String statusLabel(String status) {
    switch (status) {
      case 'aktif':
        return 'Aktif';
      case 'sakit':
        return 'Sakit';
      case 'mati':
        return 'Mati';
      case 'terjual':
        return 'Terjual';
      default:
        return status;
    }
  }
}
