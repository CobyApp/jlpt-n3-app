/// JLPT N3 영역 카테고리 정의 + 한국어 라벨. src/lib/categories.ts와 동기화.
library;

enum CategoryGroup { vocab, grammar, reading, listening }

extension CategoryGroupX on CategoryGroup {
  String get label => switch (this) {
        CategoryGroup.vocab => '어휘',
        CategoryGroup.grammar => '문법',
        CategoryGroup.reading => '독해',
        CategoryGroup.listening => '청해',
      };
}

class CategoryDef {
  final String slug;
  final String category; // 영문/내부 카테고리 키
  final CategoryGroup group;

  const CategoryDef({
    required this.slug,
    required this.category,
    required this.group,
  });
}

const List<CategoryDef> allCategories = [
  CategoryDef(slug: 'kanji-reading', category: 'Kanji Reading', group: CategoryGroup.vocab),
  CategoryDef(slug: 'orthography', category: 'Orthography', group: CategoryGroup.vocab),
  CategoryDef(slug: 'contextual', category: 'Contextually-defined Expressions', group: CategoryGroup.vocab),
  CategoryDef(slug: 'paraphrases', category: 'Paraphrases', group: CategoryGroup.vocab),
  CategoryDef(slug: 'usage', category: 'Usage', group: CategoryGroup.vocab),
  CategoryDef(slug: 'grammar-form', category: 'Sentential Grammar 1 (Selecting grammar form)', group: CategoryGroup.grammar),
  CategoryDef(slug: 'sentence-build', category: 'Sentential Grammar 2 (Sentence composition)', group: CategoryGroup.grammar),
  CategoryDef(slug: 'text-grammar', category: 'Text Grammar', group: CategoryGroup.grammar),
  CategoryDef(slug: 'short-passage', category: 'Comprehension (Short passages)', group: CategoryGroup.reading),
  CategoryDef(slug: 'mid-passage', category: 'Comprehension (Mid-size passages)', group: CategoryGroup.reading),
  CategoryDef(slug: 'long-passage', category: 'Comprehension (Long passages)', group: CategoryGroup.reading),
  CategoryDef(slug: 'info-retrieval', category: 'Information Retrieval', group: CategoryGroup.reading),
  CategoryDef(slug: 'listen-task', category: 'task-based-comprehension', group: CategoryGroup.listening),
  CategoryDef(slug: 'listen-key', category: 'comprehension-of-key-points', group: CategoryGroup.listening),
  CategoryDef(slug: 'listen-outline', category: 'comprehension-general-outline', group: CategoryGroup.listening),
  CategoryDef(slug: 'listen-verbal', category: 'verbal-expressions', group: CategoryGroup.listening),
  CategoryDef(slug: 'listen-quick', category: 'quick-response', group: CategoryGroup.listening),
];

/// 청해 슬러그 (cat:listen-* 라우팅에 사용)
const Set<String> listeningSlugs = {
  'listen-task',
  'listen-key',
  'listen-outline',
  'listen-verbal',
  'listen-quick',
};

const Map<String, String> _koLabels = {
  'Kanji Reading': '한자 읽기',
  'Orthography': '표기',
  'Contextually-defined Expressions': '문맥 규정',
  'Paraphrases': '유의 표현',
  'Usage': '용법',
  'Sentential Grammar 1 (Selecting grammar form)': '문법 형식 판단',
  'Sentential Grammar 2 (Sentence composition)': '문장 만들기',
  'Text Grammar': '글의 문법',
  'Comprehension (Short passages)': '단문 독해',
  'Comprehension (Mid-size passages)': '중간 길이 독해',
  'Comprehension (Long passages)': '장문 독해',
  'Information Retrieval': '정보 검색',
  'task-based-comprehension': '청해 — 과제 이해',
  'comprehension-of-key-points': '청해 — 포인트 이해',
  'comprehension-general-outline': '청해 — 개요 이해',
  'verbal-expressions': '청해 — 발화 표현',
  'quick-response': '청해 — 즉시 응답',
};

const Map<String, String> listeningShortKo = {
  'task-based-comprehension': '과제 이해',
  'comprehension-of-key-points': '포인트 이해',
  'comprehension-general-outline': '개요 이해',
  'verbal-expressions': '발화 표현',
  'quick-response': '즉시 응답',
};

String categoryKo(String en) => _koLabels[en] ?? en;

String? categoryFromSlug(String slug) {
  for (final c in allCategories) {
    if (c.slug == slug) return c.category;
  }
  return null;
}

CategoryDef? categoryDefFromSlug(String slug) {
  for (final c in allCategories) {
    if (c.slug == slug) return c;
  }
  return null;
}

/// 카테고리 영문 키 → 그룹 (어휘/문법/독해/청해).
CategoryGroup? groupOfCategory(String category) {
  for (final c in allCategories) {
    if (c.category == category) return c.group;
  }
  return null;
}

String? listeningTypeFromSlug(String slug) {
  final c = categoryDefFromSlug(slug);
  if (c == null || c.group != CategoryGroup.listening) return null;
  return c.category;
}

String sectionLabelKo(int num, String category) =>
    '問題$num ${categoryKo(category)}';

/// 회차별 인덱스 카드에서 보이는 짧은 제목 — 한국어 형식.
/// 예) "JLPT N3 Mock Test – July 2025" → "2025년 7월"
///     "JLPT Practice Workbook 2018 Volume 2" → "워크북 2018-2"
String shortTitle(String title) {
  // 1) "Month YYYY" 패턴 → "YYYY년 M월"
  const months = {
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3, 'mar': 3,
    'april': 4, 'apr': 4,
    'may': 5,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };
  final monthYearRe = RegExp(
    r'(?:JLPT\s*N3\s*Mock\s*Test\s*[–\-]\s*)?'
    r'(' + months.keys.join('|') + r')\s+(\d{4})',
    caseSensitive: false,
  );
  final m = monthYearRe.firstMatch(title);
  if (m != null) {
    final mo = months[m.group(1)!.toLowerCase()]!;
    final yr = m.group(2)!;
    return '$yr년 $mo월';
  }
  // 2) Practice Workbook 패턴 → "워크북 2018-2"
  final wb = RegExp(
    r'JLPT\s*Practice\s*Workbook\s*(\d{4})\s*(?:Volume|Vol)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(title);
  if (wb != null) {
    return '워크북 ${wb.group(1)}-${wb.group(2)}';
  }
  // 3) Fallback — Mock Test prefix 만 제거
  return title
      .replaceAll(
          RegExp(r'^JLPT\s*N3\s*Mock\s*Test\s*[–-]\s*',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'^JLPT\s*Practice\s*Workbook\s*',
              caseSensitive: false),
          '워크북 ')
      .trim();
}
