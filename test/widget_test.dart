import 'package:flutter_test/flutter_test.dart';
import 'package:closet_map/services/season_service.dart';
import 'package:closet_map/models/clothing.dart';

void main() {
  group('SeasonService', () {
    test('currentSeason returns a valid season', () {
      final season = SeasonService.currentSeason();
      expect(ClothingSeason.values, contains(season));
    });

    test('prevSeason returns a valid season', () {
      final prev = SeasonService.prevSeason();
      expect(ClothingSeason.values, contains(prev));
    });

    test('prevSeason is different from currentSeason', () {
      expect(SeasonService.prevSeason(), isNot(SeasonService.currentSeason()));
    });

    test('matchesCurrent returns true for all-season clothing', () {
      expect(SeasonService.matchesCurrent([ClothingSeason.all]), isTrue);
    });

    test('matchesCurrent returns true for current season', () {
      final current = SeasonService.currentSeason();
      expect(SeasonService.matchesCurrent([current]), isTrue);
    });

    test('matchesCurrent returns false for only previous season', () {
      final prev = SeasonService.prevSeason();
      expect(SeasonService.matchesCurrent([prev]), isFalse);
    });
  });

  group('Clothing CPW', () {
    test('costPerWear is null when wearCount is zero', () {
      final c = Clothing(
        name: '테스트 옷',
        category: ClothingCategory.top,
        seasons: [ClothingSeason.all],
        status: ClothingStatus.active,
        createdAt: DateTime.now(),
        purchasePrice: 50000,
        wearCount: 0,
      );
      expect(c.costPerWear, isNull);
    });

    test('costPerWear calculates correctly', () {
      final c = Clothing(
        name: '테스트 옷',
        category: ClothingCategory.top,
        seasons: [ClothingSeason.all],
        status: ClothingStatus.active,
        createdAt: DateTime.now(),
        purchasePrice: 50000,
        wearCount: 10,
      );
      expect(c.costPerWear, equals(5000));
    });
  });
}
