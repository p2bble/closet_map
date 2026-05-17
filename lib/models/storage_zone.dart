const List<int> _kZoneColors = [
  0x882196F3,
  0x884CAF50,
  0x88FF9800,
  0x889C27B0,
  0x88F44336,
  0x8800BCD4,
  0x88795548,
  0x88607D8B,
];

class StorageZone {
  final int? id;
  final int storagePlaceId;
  final String name;
  final double x;
  final double y;
  final double w;
  final double h;
  final int colorValue;
  final int sortOrder;

  const StorageZone({
    this.id,
    required this.storagePlaceId,
    required this.name,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.colorValue,
    required this.sortOrder,
  });

  static int colorForIndex(int i) => _kZoneColors[i % _kZoneColors.length];

  bool containsPoint(double px, double py) =>
      px >= x && px <= x + w && py >= y && py <= y + h;

  Map<String, dynamic> toMap() => {
        'id': id,
        'storage_place_id': storagePlaceId,
        'name': name,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'color_value': colorValue,
        'sort_order': sortOrder,
      };

  factory StorageZone.fromMap(Map<String, dynamic> m) => StorageZone(
        id: m['id'] as int?,
        storagePlaceId: m['storage_place_id'] as int,
        name: m['name'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
        colorValue: m['color_value'] as int,
        sortOrder: m['sort_order'] as int,
      );

  StorageZone copyWith({
    int? id,
    String? name,
    double? x,
    double? y,
    double? w,
    double? h,
    int? colorValue,
    int? sortOrder,
  }) {
    return StorageZone(
      id: id ?? this.id,
      storagePlaceId: storagePlaceId,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
