import '../models/clothing.dart';

class SeasonService {
  static ClothingSeason currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 4) return ClothingSeason.spring;
    if (month >= 5 && month <= 8) return ClothingSeason.summer;
    if (month >= 9 && month <= 10) return ClothingSeason.autumn;
    return ClothingSeason.winter;
  }

  static String currentSeasonLabel() => currentSeason().label;

  // 현재 계절에 맞는 옷인지 여부
  static bool matchesCurrent(List<ClothingSeason> seasons) {
    if (seasons.contains(ClothingSeason.all)) return true;
    return seasons.contains(currentSeason());
  }

  // 보관해야 할 계절 (지난 계절)
  static ClothingSeason prevSeason() {
    final cur = currentSeason();
    // all 제외한 4개 기준 순환 (spring=0, summer=1, autumn=2, winter=3)
    final seasons = [
      ClothingSeason.spring,
      ClothingSeason.summer,
      ClothingSeason.autumn,
      ClothingSeason.winter,
    ];
    final curIdx = seasons.indexOf(cur);
    return seasons[(curIdx - 1 + 4) % 4];
  }

  static String seasonChangeMessage() {
    final cur = currentSeason();
    return '${cur.label} 시즌이에요! 지난 계절 옷을 보관하고 ${cur.label} 옷을 꺼내보세요.';
  }
}
