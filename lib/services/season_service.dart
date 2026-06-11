import 'package:flutter/material.dart';
import '../models/clothing.dart';

/// 계절별 컬러 테마 — 소프트 틴트 배경 + 강조색 + 본문용 딥 톤
class SeasonTheme {
  final Color tint;
  final Color accent;
  final Color deep;
  final IconData icon;
  const SeasonTheme(this.tint, this.accent, this.deep, this.icon);
}

class SeasonService {
  static const themes = <ClothingSeason, SeasonTheme>{
    ClothingSeason.spring: SeasonTheme(Color(0xFFFCEEF2), Color(0xFFE2698F),
        Color(0xFFA84467), Icons.local_florist_rounded),
    ClothingSeason.summer: SeasonTheme(Color(0xFFE3F4F1), Color(0xFF1FA59B),
        Color(0xFF0B6E67), Icons.sunny),
    ClothingSeason.autumn: SeasonTheme(Color(0xFFFAF0E1), Color(0xFFD9842B),
        Color(0xFF94570F), Icons.eco_rounded),
    ClothingSeason.winter: SeasonTheme(Color(0xFFEAF0FB), Color(0xFF5C8EE6),
        Color(0xFF36589C), Icons.ac_unit_rounded),
  };

  static SeasonTheme currentTheme() => themes[currentSeason()]!;

  static ClothingSeason currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 4) return ClothingSeason.spring;
    if (month >= 5 && month <= 8) return ClothingSeason.summer;
    if (month >= 9 && month <= 10) return ClothingSeason.autumn;
    return ClothingSeason.winter;
  }

  static String currentSeasonLabel() => currentSeason().label;

  /// 현재 시즌 시작일 (계절 전환 진행률 집계 기준)
  static DateTime currentSeasonStart() {
    final now = DateTime.now();
    final m = now.month;
    if (m >= 3 && m <= 4) return DateTime(now.year, 3, 1);
    if (m >= 5 && m <= 8) return DateTime(now.year, 5, 1);
    if (m >= 9 && m <= 10) return DateTime(now.year, 9, 1);
    // 겨울: 11월 시작, 1~2월은 전년도 11월
    return DateTime(m >= 11 ? now.year : now.year - 1, 11, 1);
  }

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
