class Outfit {
  final int? id;
  final String? name;
  final String? memo;
  final DateTime createdAt;

  const Outfit({
    this.id,
    this.name,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory Outfit.fromMap(Map<String, dynamic> m) => Outfit(
        id: m['id'] as int?,
        name: m['name'] as String?,
        memo: m['memo'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
