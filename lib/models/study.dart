/// 급수별 학습 콘텐츠 모델 (단어/표현/문법/꿀팁, 다국어).
library;

class StudyContent {
  final List<StudyVocabTheme> vocab;
  final List<StudyExpression> expressions;
  final List<StudyGrammar> grammar;
  final List<StudyTip> tips;

  StudyContent({
    required this.vocab,
    required this.expressions,
    required this.grammar,
    required this.tips,
  });

  factory StudyContent.fromJson(Map<String, dynamic> j) => StudyContent(
        vocab: (j['vocab'] as List? ?? [])
            .map((e) => StudyVocabTheme.fromJson(e as Map<String, dynamic>))
            .toList(),
        expressions: (j['expressions'] as List? ?? [])
            .map((e) => StudyExpression.fromJson(e as Map<String, dynamic>))
            .toList(),
        grammar: (j['grammar'] as List? ?? [])
            .map((e) => StudyGrammar.fromJson(e as Map<String, dynamic>))
            .toList(),
        tips: (j['tips'] as List? ?? [])
            .map((e) => StudyTip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StudyVocabTheme {
  final String themeKo, themeEn, themeZh;
  final List<StudyVocabItem> items;

  StudyVocabTheme({
    required this.themeKo,
    required this.themeEn,
    required this.themeZh,
    required this.items,
  });

  factory StudyVocabTheme.fromJson(Map<String, dynamic> j) => StudyVocabTheme(
        themeKo: j['theme_ko'] as String? ?? '',
        themeEn: j['theme_en'] as String? ?? '',
        themeZh: j['theme_zh'] as String? ?? '',
        items: (j['items'] as List? ?? [])
            .map((e) => StudyVocabItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String themeFor(String lang) {
    if (lang == 'en' && themeEn.isNotEmpty) return themeEn;
    if (lang == 'zh' && themeZh.isNotEmpty) return themeZh;
    return themeKo;
  }
}

class StudyVocabItem {
  final String w, r;
  final String ko, en, zh;
  final String exJa, exKo, exEn, exZh;

  StudyVocabItem({
    required this.w,
    required this.r,
    required this.ko,
    required this.en,
    required this.zh,
    required this.exJa,
    required this.exKo,
    required this.exEn,
    required this.exZh,
  });

  factory StudyVocabItem.fromJson(Map<String, dynamic> j) => StudyVocabItem(
        w: j['w'] as String? ?? '',
        r: j['r'] as String? ?? '',
        ko: j['ko'] as String? ?? '',
        en: j['en'] as String? ?? '',
        zh: j['zh'] as String? ?? '',
        exJa: j['ex_ja'] as String? ?? '',
        exKo: j['ex_ko'] as String? ?? '',
        exEn: j['ex_en'] as String? ?? '',
        exZh: j['ex_zh'] as String? ?? '',
      );

  String meaningFor(String lang) {
    if (lang == 'en' && en.isNotEmpty) return en;
    if (lang == 'zh' && zh.isNotEmpty) return zh;
    return ko;
  }

  String exampleFor(String lang) {
    if (lang == 'en' && exEn.isNotEmpty) return exEn;
    if (lang == 'zh' && exZh.isNotEmpty) return exZh;
    return exKo;
  }
}

class StudyExpression {
  final String ja, r;
  final String ko, en, zh;
  final String exJa, exKo, exEn, exZh;
  final String tipKo, tipEn, tipZh;

  StudyExpression({
    required this.ja,
    required this.r,
    required this.ko,
    required this.en,
    required this.zh,
    required this.exJa,
    required this.exKo,
    required this.exEn,
    required this.exZh,
    required this.tipKo,
    required this.tipEn,
    required this.tipZh,
  });

  factory StudyExpression.fromJson(Map<String, dynamic> j) => StudyExpression(
        ja: j['ja'] as String? ?? '',
        r: j['r'] as String? ?? '',
        ko: j['ko'] as String? ?? '',
        en: j['en'] as String? ?? '',
        zh: j['zh'] as String? ?? '',
        exJa: j['ex_ja'] as String? ?? '',
        exKo: j['ex_ko'] as String? ?? '',
        exEn: j['ex_en'] as String? ?? '',
        exZh: j['ex_zh'] as String? ?? '',
        tipKo: j['tip_ko'] as String? ?? '',
        tipEn: j['tip_en'] as String? ?? '',
        tipZh: j['tip_zh'] as String? ?? '',
      );

  String meaningFor(String lang) {
    if (lang == 'en' && en.isNotEmpty) return en;
    if (lang == 'zh' && zh.isNotEmpty) return zh;
    return ko;
  }

  String exampleFor(String lang) {
    if (lang == 'en' && exEn.isNotEmpty) return exEn;
    if (lang == 'zh' && exZh.isNotEmpty) return exZh;
    return exKo;
  }

  String tipFor(String lang) {
    if (lang == 'en' && tipEn.isNotEmpty) return tipEn;
    if (lang == 'zh' && tipZh.isNotEmpty) return tipZh;
    return tipKo;
  }
}

class StudyGrammar {
  final String title;
  final String meaningKo, meaningEn, meaningZh;
  final String exJa, exKo, exEn, exZh;
  final String noteKo, noteEn, noteZh;

  StudyGrammar({
    required this.title,
    required this.meaningKo,
    required this.meaningEn,
    required this.meaningZh,
    required this.exJa,
    required this.exKo,
    required this.exEn,
    required this.exZh,
    required this.noteKo,
    required this.noteEn,
    required this.noteZh,
  });

  factory StudyGrammar.fromJson(Map<String, dynamic> j) => StudyGrammar(
        title: j['title'] as String? ?? '',
        meaningKo: j['meaning_ko'] as String? ?? '',
        meaningEn: j['meaning_en'] as String? ?? '',
        meaningZh: j['meaning_zh'] as String? ?? '',
        exJa: j['ex_ja'] as String? ?? '',
        exKo: j['ex_ko'] as String? ?? '',
        exEn: j['ex_en'] as String? ?? '',
        exZh: j['ex_zh'] as String? ?? '',
        noteKo: j['note_ko'] as String? ?? '',
        noteEn: j['note_en'] as String? ?? '',
        noteZh: j['note_zh'] as String? ?? '',
      );

  String meaningFor(String lang) {
    if (lang == 'en' && meaningEn.isNotEmpty) return meaningEn;
    if (lang == 'zh' && meaningZh.isNotEmpty) return meaningZh;
    return meaningKo;
  }

  String exampleFor(String lang) {
    if (lang == 'en' && exEn.isNotEmpty) return exEn;
    if (lang == 'zh' && exZh.isNotEmpty) return exZh;
    return exKo;
  }

  String noteFor(String lang) {
    if (lang == 'en' && noteEn.isNotEmpty) return noteEn;
    if (lang == 'zh' && noteZh.isNotEmpty) return noteZh;
    return noteKo;
  }
}

class StudyTip {
  final String titleKo, titleEn, titleZh;
  final String bodyKo, bodyEn, bodyZh;

  StudyTip({
    required this.titleKo,
    required this.titleEn,
    required this.titleZh,
    required this.bodyKo,
    required this.bodyEn,
    required this.bodyZh,
  });

  factory StudyTip.fromJson(Map<String, dynamic> j) => StudyTip(
        titleKo: j['title_ko'] as String? ?? '',
        titleEn: j['title_en'] as String? ?? '',
        titleZh: j['title_zh'] as String? ?? '',
        bodyKo: j['body_ko'] as String? ?? '',
        bodyEn: j['body_en'] as String? ?? '',
        bodyZh: j['body_zh'] as String? ?? '',
      );

  String titleFor(String lang) {
    if (lang == 'en' && titleEn.isNotEmpty) return titleEn;
    if (lang == 'zh' && titleZh.isNotEmpty) return titleZh;
    return titleKo;
  }

  String bodyFor(String lang) {
    if (lang == 'en' && bodyEn.isNotEmpty) return bodyEn;
    if (lang == 'zh' && bodyZh.isNotEmpty) return bodyZh;
    return bodyKo;
  }
}
