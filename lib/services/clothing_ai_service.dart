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
  // responseSchema(JSON 모드)로 출력 형식을 강제해 파싱 실패를 차단
  static final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(properties: {
        'category': Schema.enumString(enumValues: [
          '상의', '하의', '아우터', '원피스세트', '이너속옷', '신발', '가방악세서리', '기타',
        ]),
        'seasons': Schema.array(
          items: Schema.enumString(
              enumValues: ['봄', '여름', '가을', '겨울', '사계절']),
        ),
        'color': Schema.enumString(enumValues: [
          '흰색', '검정', '회색', '베이지', '갈색', '빨강', '주황',
          '노랑', '초록', '파랑', '남색', '보라', '분홍', '기타',
        ]),
        'name': Schema.string(description: '옷 이름 제안 (예: 흰색 면 티셔츠, 검정 청바지)'),
      }),
    ),
  );

  static const _prompt = '''
이 옷 사진을 분석해서 카테고리, 어울리는 계절(복수 가능), 대표 색상, 옷 이름 제안을 알려줘.
''';

  static Future<ClothingAiResult?> classify(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final imagePart = InlineDataPart('image/jpeg', bytes);
      final response = await _model.generateContent([
        Content.multi([imagePart, TextPart(_prompt)]),
      ]);

      final data = jsonDecode(response.text ?? '') as Map<String, dynamic>;

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
