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

enum ClothingColor {
  white, black, gray, beige, brown,
  red, orange, yellow, green, blue, navy, purple, pink,
  other,
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

extension ClothingColorLabel on ClothingColor {
  String get label => const {
        ClothingColor.white: '흰색',
        ClothingColor.black: '검정',
        ClothingColor.gray: '회색',
        ClothingColor.beige: '베이지',
        ClothingColor.brown: '갈색',
        ClothingColor.red: '빨강',
        ClothingColor.orange: '주황',
        ClothingColor.yellow: '노랑',
        ClothingColor.green: '초록',
        ClothingColor.blue: '파랑',
        ClothingColor.navy: '남색',
        ClothingColor.purple: '보라',
        ClothingColor.pink: '분홍',
        ClothingColor.other: '기타',
      }[this]!;

  // 0xFF_RRGGBB 형태의 int 값 (Color 생성 없이 DB 저장용)
  int get colorValue => const {
        ClothingColor.white: 0xFFF5F5F5,
        ClothingColor.black: 0xFF212121,
        ClothingColor.gray: 0xFF9E9E9E,
        ClothingColor.beige: 0xFFD4C5A9,
        ClothingColor.brown: 0xFF795548,
        ClothingColor.red: 0xFFE53935,
        ClothingColor.orange: 0xFFFF7043,
        ClothingColor.yellow: 0xFFFFCA28,
        ClothingColor.green: 0xFF43A047,
        ClothingColor.blue: 0xFF1E88E5,
        ClothingColor.navy: 0xFF283593,
        ClothingColor.purple: 0xFF8E24AA,
        ClothingColor.pink: 0xFFE91E63,
        ClothingColor.other: 0xFFBDBDBD,
      }[this]!;
}

class Clothing {
  final int? id;
  final String name;
  final ClothingCategory category;
  final List<ClothingSeason> seasons;
  final ClothingColor? color;
  final String? imagePath;
  final String? memo;
  final String? brand;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final ClothingStatus status;
  final int? storagePlaceId;
  final int? storageZoneId;
  final String? storageNote;
  final DateTime createdAt;
  final int wearCount;
  final DateTime? lastWornAt;

  const Clothing({
    this.id,
    required this.name,
    required this.category,
    required this.seasons,
    this.color,
    this.imagePath,
    this.memo,
    this.brand,
    this.purchasePrice,
    this.purchaseDate,
    this.status = ClothingStatus.active,
    this.storagePlaceId,
    this.storageZoneId,
    this.storageNote,
    required this.createdAt,
    this.wearCount = 0,
    this.lastWornAt,
  });

  bool get isStored => status == ClothingStatus.stored;

  double? get costPerWear =>
      (purchasePrice != null && purchasePrice! > 0 && wearCount > 0)
          ? purchasePrice! / wearCount
          : null;

  static const _absent = Object();

  Clothing copyWith({
    int? id,
    String? name,
    ClothingCategory? category,
    List<ClothingSeason>? seasons,
    Object? color = _absent,
    Object? imagePath = _absent,
    Object? memo = _absent,
    Object? brand = _absent,
    Object? purchasePrice = _absent,
    Object? purchaseDate = _absent,
    ClothingStatus? status,
    Object? storagePlaceId = _absent,
    Object? storageZoneId = _absent,
    Object? storageNote = _absent,
    int? wearCount,
    Object? lastWornAt = _absent,
  }) {
    return Clothing(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      seasons: seasons ?? this.seasons,
      color: color == _absent ? this.color : color as ClothingColor?,
      imagePath: imagePath == _absent ? this.imagePath : imagePath as String?,
      memo: memo == _absent ? this.memo : memo as String?,
      brand: brand == _absent ? this.brand : brand as String?,
      purchasePrice: purchasePrice == _absent ? this.purchasePrice : purchasePrice as double?,
      purchaseDate: purchaseDate == _absent ? this.purchaseDate : purchaseDate as DateTime?,
      status: status ?? this.status,
      storagePlaceId: storagePlaceId == _absent ? this.storagePlaceId : storagePlaceId as int?,
      storageZoneId: storageZoneId == _absent ? this.storageZoneId : storageZoneId as int?,
      storageNote: storageNote == _absent ? this.storageNote : storageNote as String?,
      createdAt: createdAt,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: lastWornAt == _absent ? this.lastWornAt : lastWornAt as DateTime?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.index,
        'seasons': seasons.map((s) => s.index).join(','),
        'color': color?.index,
        'image_path': imagePath,
        'memo': memo,
        'brand': brand,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate?.toIso8601String(),
        'status': status.index,
        'storage_place_id': storagePlaceId,
        'storage_zone_id': storageZoneId,
        'storage_note': storageNote,
        'created_at': createdAt.toIso8601String(),
        'wear_count': wearCount,
        'last_worn_at': lastWornAt?.toIso8601String(),
      };

  factory Clothing.fromMap(Map<String, dynamic> m) {
    final seasonStr = m['seasons'] as String? ?? '';
    final seasons = seasonStr.isEmpty
        ? <ClothingSeason>[]
        : seasonStr
            .split(',')
            .map((s) => ClothingSeason.values[int.parse(s)])
            .toList();
    final colorIdx = m['color'] as int?;
    return Clothing(
      id: m['id'] as int?,
      name: m['name'] as String,
      category: ClothingCategory.values[m['category'] as int],
      seasons: seasons,
      color: colorIdx != null ? ClothingColor.values[colorIdx] : null,
      imagePath: m['image_path'] as String?,
      memo: m['memo'] as String?,
      brand: m['brand'] as String?,
      purchasePrice: m['purchase_price'] as double?,
      purchaseDate: m['purchase_date'] != null
          ? DateTime.tryParse(m['purchase_date'] as String)
          : null,
      status: ClothingStatus.values[m['status'] as int],
      storagePlaceId: m['storage_place_id'] as int?,
      storageZoneId: m['storage_zone_id'] as int?,
      storageNote: m['storage_note'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      wearCount: (m['wear_count'] as int?) ?? 0,
      lastWornAt: m['last_worn_at'] != null
          ? DateTime.tryParse(m['last_worn_at'] as String)
          : null,
    );
  }
}
