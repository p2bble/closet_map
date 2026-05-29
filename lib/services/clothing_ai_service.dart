import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/clothing.dart';

class ClothingAiResult {
  final ClothingCategory category;
  final List<ClothingSeason> seasons;
  final ClothingColor? color;
  final String? suggestedName;

  ClothingAiResult({
    required this.category,
    required this.seasons,
    this.color,
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
  "color": "흰색" | "검정" | "회색" | "베이지" | "갈색" | "빨강" | "주황" | "노랑" | "초록" | "파랑" | "남색" | "보라" | "분홍" | "기타",
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
        color: _toColor(data['color'] as String? ?? ''),
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

  static ClothingColor? _toColor(String v) => const {
        '흰색': ClothingColor.white,
        '검정': ClothingColor.black,
        '회색': ClothingColor.gray,
        '베이지': ClothingColor.beige,
        '갈색': ClothingColor.brown,
        '빨강': ClothingColor.red,
        '주황': ClothingColor.orange,
        '노랑': ClothingColor.yellow,
        '초록': ClothingColor.green,
        '파랑': ClothingColor.blue,
        '남색': ClothingColor.navy,
        '보라': ClothingColor.purple,
        '분홍': ClothingColor.pink,
        '기타': ClothingColor.other,
      }[v];
}
