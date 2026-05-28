/// Data models ported from src/types.ts in the web app.
/// All fields are intentionally non-nullable where the source guarantees
/// a value to keep call sites tidy; optional fields stay nullable.
library;

class IndexEntry {
  final String id;
  final String title;
  final String file;
  final int questions;
  final int passages;
  final String source;
  final int listeningQuestions;
  final int listeningSubsections;

  IndexEntry({
    required this.id,
    required this.title,
    required this.file,
    required this.questions,
    required this.passages,
    required this.source,
    required this.listeningQuestions,
    required this.listeningSubsections,
  });

  factory IndexEntry.fromJson(Map<String, dynamic> j) => IndexEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        file: j['file'] as String,
        questions: (j['questions'] as num).toInt(),
        passages: (j['passages'] as num).toInt(),
        source: j['source'] as String? ?? '',
        listeningQuestions: ((j['listening_questions'] as num?) ?? 0).toInt(),
        listeningSubsections:
            ((j['listening_subsections'] as num?) ?? 0).toInt(),
      );

  int get totalQuestions => questions + listeningQuestions;
}

class IndexFile {
  final List<IndexEntry> exams;
  final Map<String, int> categoryTotals;

  IndexFile({required this.exams, required this.categoryTotals});

  factory IndexFile.fromJson(Map<String, dynamic> j) => IndexFile(
        exams: (j['exams'] as List)
            .map((e) => IndexEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        categoryTotals: ((j['category_totals'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
}

class Passage {
  final String ja;
  final String en;
  final String? ko;

  Passage({required this.ja, required this.en, this.ko});

  factory Passage.fromJson(Map<String, dynamic> j) => Passage(
        ja: j['ja'] as String? ?? '',
        en: j['en'] as String? ?? '',
        ko: j['ko'] as String?,
      );
}

class Question {
  final int n;
  final String id;
  final String? passage;
  final String stem;
  final String? stemU;
  final List<String> opts;
  final int correct;
  final String category;
  final String expl;
  final String? explKo;
  final String? srcLabel;
  final int? srcN;

  Question({
    required this.n,
    required this.id,
    required this.passage,
    required this.stem,
    required this.stemU,
    required this.opts,
    required this.correct,
    required this.category,
    required this.expl,
    required this.explKo,
    required this.srcLabel,
    required this.srcN,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        n: (j['n'] as num).toInt(),
        id: j['id'] as String,
        passage: j['passage'] as String?,
        stem: j['stem'] as String? ?? '',
        stemU: j['stem_u'] as String?,
        opts: ((j['opts'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        correct: (j['correct'] as num).toInt(),
        category: j['category'] as String? ?? '',
        expl: j['expl'] as String? ?? '',
        explKo: j['expl_ko'] as String?,
        srcLabel: j['src_label'] as String?,
        srcN: (j['src_n'] as num?)?.toInt(),
      );

  Question copyWith({int? n, String? srcLabel, int? srcN}) => Question(
        n: n ?? this.n,
        id: id,
        passage: passage,
        stem: stem,
        stemU: stemU,
        opts: opts,
        correct: correct,
        category: category,
        expl: expl,
        explKo: explKo,
        srcLabel: srcLabel ?? this.srcLabel,
        srcN: srcN ?? this.srcN,
      );
}

class ListeningQuestion {
  final String id;
  final int n;
  final List<String> opts;
  final List<String> optsHtml;
  final int correct;
  final String scriptHtml;
  final String? translationKo;
  final String? explKo;
  final String explanationEn;

  ListeningQuestion({
    required this.id,
    required this.n,
    required this.opts,
    required this.optsHtml,
    required this.correct,
    required this.scriptHtml,
    required this.translationKo,
    required this.explKo,
    required this.explanationEn,
  });

  factory ListeningQuestion.fromJson(Map<String, dynamic> j) =>
      ListeningQuestion(
        id: j['id'] as String,
        n: (j['n'] as num).toInt(),
        opts: ((j['opts'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        optsHtml: ((j['opts_html'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        correct: (j['correct'] as num).toInt(),
        scriptHtml: j['script_html'] as String? ?? '',
        translationKo: j['translation_ko'] as String?,
        explKo: j['expl_ko'] as String?,
        explanationEn: j['explanation_en'] as String? ?? '',
      );
}

class ListeningSubsection {
  final int order;
  final String title;
  final String englishTitle;
  final String type;
  final String introHtml;
  final String audioUrl;
  final List<ListeningQuestion> questions;

  ListeningSubsection({
    required this.order,
    required this.title,
    required this.englishTitle,
    required this.type,
    required this.introHtml,
    required this.audioUrl,
    required this.questions,
  });

  factory ListeningSubsection.fromJson(Map<String, dynamic> j) =>
      ListeningSubsection(
        order: (j['order'] as num).toInt(),
        title: j['title'] as String? ?? '',
        englishTitle: j['english_title'] as String? ?? '',
        type: j['type'] as String? ?? '',
        introHtml: j['intro_html'] as String? ?? '',
        audioUrl: j['audio_url'] as String? ?? '',
        questions: ((j['questions'] as List?) ?? const [])
            .map((q) =>
                ListeningQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class Listening {
  final String sectionUrl;
  final String title;
  final List<ListeningSubsection> subsections;

  Listening({
    required this.sectionUrl,
    required this.title,
    required this.subsections,
  });

  factory Listening.fromJson(Map<String, dynamic> j) => Listening(
        sectionUrl: j['section_url'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subsections: ((j['subsections'] as List?) ?? const [])
            .map((s) =>
                ListeningSubsection.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class Exam {
  final String testId;
  final String title;
  final String sourceUrl;
  final String scrapedAt;
  final Map<String, Passage> passages;
  final List<Question> questions;
  final Listening? listening;

  Exam({
    required this.testId,
    required this.title,
    required this.sourceUrl,
    required this.scrapedAt,
    required this.passages,
    required this.questions,
    required this.listening,
  });

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        testId: j['test_id'] as String,
        title: j['title'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
        scrapedAt: j['scraped_at'] as String? ?? '',
        passages: ((j['passages'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(
            k.toString(),
            Passage.fromJson(v as Map<String, dynamic>),
          ),
        ),
        questions: ((j['questions'] as List?) ?? const [])
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
        listening: j['listening'] != null
            ? Listening.fromJson(j['listening'] as Map<String, dynamic>)
            : null,
      );
}

class VocabEntry {
  final String w;
  final String r;
  final String m;
  final String? mKo;

  VocabEntry({
    required this.w,
    required this.r,
    required this.m,
    required this.mKo,
  });

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
        w: j['w'] as String,
        r: j['r'] as String? ?? '',
        m: j['m'] as String? ?? '',
        mKo: j['m_ko'] as String?,
      );
}

/// Persisted answer record.
class AnswerRec {
  final int picked;
  final bool correct;
  final int ts;

  AnswerRec({required this.picked, required this.correct, required this.ts});

  Map<String, dynamic> toJson() =>
      {'picked': picked, 'correct': correct, 'ts': ts};

  factory AnswerRec.fromJson(Map<String, dynamic> j) => AnswerRec(
        picked: (j['picked'] as num).toInt(),
        correct: j['correct'] as bool,
        ts: ((j['ts'] as num?) ?? 0).toInt(),
      );
}

class WordbookEntry {
  final String w;
  final int ts;

  WordbookEntry({required this.w, required this.ts});

  Map<String, dynamic> toJson() => {'w': w, 'ts': ts};

  factory WordbookEntry.fromJson(Map<String, dynamic> j) => WordbookEntry(
        w: j['w'] as String,
        ts: ((j['ts'] as num?) ?? 0).toInt(),
      );
}

/// SRS (Spaced Repetition) per-word state. Matches web app's `KEY_SRS`.
/// level: -1 = never reviewed, 0..5 = mastery (5 = mastered)
class SrsRec {
  final int level;
  final int seen;
  final int correct;
  final int wrong;
  final int lastTs;

  const SrsRec({
    this.level = -1,
    this.seen = 0,
    this.correct = 0,
    this.wrong = 0,
    this.lastTs = 0,
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'seen': seen,
        'correct': correct,
        'wrong': wrong,
        'lastTs': lastTs,
      };

  factory SrsRec.fromJson(Map<String, dynamic> j) => SrsRec(
        level: (j['level'] as num?)?.toInt() ?? -1,
        seen: (j['seen'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        wrong: (j['wrong'] as num?)?.toInt() ?? 0,
        lastTs: (j['lastTs'] as num?)?.toInt() ?? 0,
      );

  SrsRec copyWith({int? level, int? seen, int? correct, int? wrong, int? lastTs}) =>
      SrsRec(
        level: level ?? this.level,
        seen: seen ?? this.seen,
        correct: correct ?? this.correct,
        wrong: wrong ?? this.wrong,
        lastTs: lastTs ?? this.lastTs,
      );
}

enum SrsAction { again, skip, easy }

class LastPos {
  final String examId;
  final int questionN;
  final int ts;

  LastPos({required this.examId, required this.questionN, required this.ts});

  Map<String, dynamic> toJson() =>
      {'examId': examId, 'questionN': questionN, 'ts': ts};

  factory LastPos.fromJson(Map<String, dynamic> j) => LastPos(
        examId: j['examId'] as String,
        questionN: (j['questionN'] as num).toInt(),
        ts: ((j['ts'] as num?) ?? 0).toInt(),
      );
}
