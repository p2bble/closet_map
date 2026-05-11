import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/clothing.dart';

class ClothingAiResult {
  final ClothingCategory category;
  final List<ClothingSeason> seasons;
  final String? suggestedName;

  ClothingAiResult({
    required this.category,
    required this.seasons,
    this.suggestedName,
  });
}

class ClothingAiService {
  static final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
  );

  static const _prompt = '''
이 옷 사진을 분석해서 아래 JSON 형식으로만 응답해. 설명 없이 JSON만 반환해.

{
  "category": "상의" | "하의" | "아우터" | "원피스세트" | "이너속옷" | "신발" | "가방악세서리" | "기타",
  "seasons": ["봄", "여름", "가을", "겨울", "사계절"] 중 해당하는 것 배열,
  "name": "옷 이름 제안 (예: 흰색 면 티셔츠, 검정 청바지)"
}
''';

  static Future<ClothingAiResult?> classify(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final imagePart = InlineDataPart('image/jpeg', bytes);
      final response = await _model.generateContent([
        Content.multi([imagePart, TextPart(_prompt)]),
      ]);

      final raw = response.text ?? '';
      final jsonStr = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return ClothingAiResult(
        category: _toCategory(data['category'] as String? ?? ''),
        seasons: _toSeasons(data['seasons'] as List? ?? []),
        suggestedName: data['name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static ClothingCategory _toCategory(String v) => const {
        '상의': ClothingCategory.top,
        '하의': ClothingCategory.bottom,
        '아우터': ClothingCategory.outer,
        '원피스세트': ClothingCategory.dress,
        '이너속옷': ClothingCategory.underwear,
        '신발': ClothingCategory.shoes,
        '가방악세서리': ClothingCategory.accessory,
      }[v] ??
      ClothingCategory.etc;

  static List<ClothingSeason> _toSeasons(List raw) => const {
        '봄': ClothingSeason.spring,
        '여름': ClothingSeason.summer,
        '가을': ClothingSeason.autumn,
        '겨울': ClothingSeason.winter,
        '사계절': ClothingSeason.all,
      }
          .entries
          .where((e) => raw.contains(e.key))
          .map((e) => e.value)
          .toList();
}
