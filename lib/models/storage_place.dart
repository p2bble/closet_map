class StoragePlace {
  final int? id;
  final String name;
  final String? imagePath;
  final String? memo;
  final DateTime createdAt;

  const StoragePlace({
    this.id,
    required this.name,
    this.imagePath,
    this.memo,
    required this.createdAt,
  });

  static const _absent = Object();

  StoragePlace copyWith({
    int? id,
    String? name,
    Object? imagePath = _absent,
    Object? memo = _absent,
  }) {
    return StoragePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath == _absent ? this.imagePath : imagePath as String?,
      memo: memo == _absent ? this.memo : memo as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'image_path': imagePath,
        'memo': memo,
        'created_at': createdAt.toIso8601String(),
      };

  factory StoragePlace.fromMap(Map<String, dynamic> m) => StoragePlace(
        id: m['id'] as int?,
        name: m['name'] as String,
        imagePath: m['image_path'] as String?,
        memo: m['memo'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
