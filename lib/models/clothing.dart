enum ClothingStatus { active, stored }

enum ClothingSeason { spring, summer, autumn, winter, all }

enum ClothingCategory {
  top,
  bottom,
  outer,
  dress,
  underwear,
  shoes,
  accessory,
  etc,
}

extension ClothingSeasonLabel on ClothingSeason {
  String get label => const {
        ClothingSeason.spring: '봄',
        ClothingSeason.summer: '여름',
        ClothingSeason.autumn: '가을',
        ClothingSeason.winter: '겨울',
        ClothingSeason.all: '사계절',
      }[this]!;
}

extension ClothingCategoryLabel on ClothingCategory {
  String get label => const {
        ClothingCategory.top: '상의',
        ClothingCategory.bottom: '하의',
        ClothingCategory.outer: '아우터',
        ClothingCategory.dress: '원피스/세트',
        ClothingCategory.underwear: '이너/속옷',
        ClothingCategory.shoes: '신발',
        ClothingCategory.accessory: '가방/악세서리',
        ClothingCategory.etc: '기타',
      }[this]!;
}

class Clothing {
  final int? id;
  final String name;
  final ClothingCategory category;
  final List<ClothingSeason> seasons;
  final String? imagePath;
  final String? memo;
  final ClothingStatus status;
  final int? storagePlaceId;
  final int? storageZoneId;
  final String? storageNote;
  final DateTime createdAt;
  final int wearCount;

  const Clothing({
    this.id,
    required this.name,
    required this.category,
    required this.seasons,
    this.imagePath,
    this.memo,
    this.status = ClothingStatus.active,
    this.storagePlaceId,
    this.storageZoneId,
    this.storageNote,
    required this.createdAt,
    this.wearCount = 0,
  });

  bool get isStored => status == ClothingStatus.stored;

  static const _absent = Object();

  Clothing copyWith({
    int? id,
    String? name,
    ClothingCategory? category,
    List<ClothingSeason>? seasons,
    Object? imagePath = _absent,
    Object? memo = _absent,
    ClothingStatus? status,
    Object? storagePlaceId = _absent,
    Object? storageZoneId = _absent,
    Object? storageNote = _absent,
    int? wearCount,
  }) {
    return Clothing(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      seasons: seasons ?? this.seasons,
      imagePath: imagePath == _absent ? this.imagePath : imagePath as String?,
      memo: memo == _absent ? this.memo : memo as String?,
      status: status ?? this.status,
      storagePlaceId: storagePlaceId == _absent ? this.storagePlaceId : storagePlaceId as int?,
      storageZoneId: storageZoneId == _absent ? this.storageZoneId : storageZoneId as int?,
      storageNote: storageNote == _absent ? this.storageNote : storageNote as String?,
      createdAt: createdAt,
      wearCount: wearCount ?? this.wearCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.index,
        'seasons': seasons.map((s) => s.index).join(','),
        'image_path': imagePath,
        'memo': memo,
        'status': status.index,
        'storage_place_id': storagePlaceId,
        'storage_zone_id': storageZoneId,
        'storage_note': storageNote,
        'created_at': createdAt.toIso8601String(),
        'wear_count': wearCount,
      };

  factory Clothing.fromMap(Map<String, dynamic> m) {
    final seasonStr = m['seasons'] as String? ?? '';
    final seasons = seasonStr.isEmpty
        ? <ClothingSeason>[]
        : seasonStr
            .split(',')
            .map((s) => ClothingSeason.values[int.parse(s)])
            .toList();
    return Clothing(
      id: m['id'] as int?,
      name: m['name'] as String,
      category: ClothingCategory.values[m['category'] as int],
      seasons: seasons,
      imagePath: m['image_path'] as String?,
      memo: m['memo'] as String?,
      status: ClothingStatus.values[m['status'] as int],
      storagePlaceId: m['storage_place_id'] as int?,
      storageZoneId: m['storage_zone_id'] as int?,
      storageNote: m['storage_note'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      wearCount: (m['wear_count'] as int?) ?? 0,
    );
  }
}
