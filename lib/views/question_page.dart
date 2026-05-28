/// 독해/어휘/문법 문제 풀이 화면.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/categories.dart';
import '../data/data_loader.dart';
import '../data/stem_format.dart';
import '../data/vocab_match.dart';
import '../models/models.dart';
import '../state/store.dart';
import '../theme.dart';
import '../widgets/explanation.dart';
import '../widgets/japanese_text.dart';
import '../widgets/vocab_sheet.dart';

class QuestionPage extends StatefulWidget {
  final String examId;
  final int n;
  final int? from;
  final int? to;
  const QuestionPage({
    super.key,
    required this.examId,
    required this.n,
    this.from,
    this.to,
  });

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  late Future<_Load> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void didUpdateWidget(covariant QuestionPage old) {
    super.didUpdateWidget(old);
    if (old.examId != widget.examId || old.n != widget.n) {
      _f = _load();
    }
  }

  Future<_Load> _load() async {
    final exam = await DataLoader.instance.loadExam(widget.examId);
    final vocab = await DataLoader.instance.loadVocab();
    final kanjiKo = await DataLoader.instance.loadKanjiKo();
    final idx = VocabIndex.build(vocab);
    final q = exam.questions.firstWhere(
      (x) => x.n == widget.n,
      orElse: () => throw Exception('문제 ${widget.n}을 찾을 수 없습니다.'),
    );
    await Store.instance.setLast(widget.examId, widget.n);
    return _Load(exam, q, idx, kanjiKo);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Load>(
      future: _f,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('${snap.error}')));
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _QuestionView(
          load: snap.data!,
          examId: widget.examId,
          n: widget.n,
          fromN: widget.from,
          toN: widget.to,
        );
      },
    );
  }
}

class _Load {
  final Exam exam;
  final Question q;
  final VocabIndex idx;
  final Map<String, List<String>> kanjiKo;
  _Load(this.exam, this.q, this.idx, this.kanjiKo);
}

class _QuestionView extends StatefulWidget {
  final _Load load;
  final String examId;
  final int n;
  final int? fromN;
  final int? toN;
  const _QuestionView({
    required this.load,
    required this.examId,
    required this.n,
    required this.fromN,
    required this.toN,
  });

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  int _picked = -1;
  bool _graded = false;

  int get _min => widget.fromN ?? 1;
  int get _max => widget.toN ?? widget.load.exam.questions.length;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _QuestionView old) {
    super.didUpdateWidget(old);
    if (old.load.q.id != widget.load.q.id) {
      _picked = -1;
      _graded = false;
      _hydrate();
    }
  }

  /// 이전에 풀어둔 답이 있으면 복원.
  void _hydrate() {
    final prog = Store.instance.getProgress(widget.examId);
    final rec = prog[widget.load.q.n];
    if (rec != null) {
      _picked = rec.picked;
      _graded = true;
    }
  }

  void _select(int i) {
    if (_graded) return;
    setState(() => _picked = i);
  }

  Future<void> _submit() async {
    if (_picked < 0 || _graded) return;
    final correct = _picked == widget.load.q.correct;
    await Store.instance.recordAnswer(
        widget.examId, widget.load.q.n, _picked, correct);
    setState(() => _graded = true);
  }

  void _navigate(int n) {
    final qs = widget.fromN != null && widget.toN != null
        ? '?from=${widget.fromN}&to=${widget.toN}'
        : '';
    context.go('/exam/${widget.examId}/q/$n$qs');
  }

  void _gotoListening(Exam exam) {
    context.go('/exam/${widget.examId}/listen/1');
  }

  /// 메인 CTA 의 onPressed — 미채점이면 채점, 채점 후면 다음 이동.
  VoidCallback? _primaryAction(_Load l) {
    if (!_graded) {
      return _picked < 0 ? null : _submit;
    }
    return () {
      if (widget.n < _max) {
        _navigate(widget.n + 1);
      } else if (l.exam.listening != null) {
        _gotoListening(l.exam);
      } else {
        context.go('/exam/${widget.examId}');
      }
    };
  }

  /// 메인 CTA 의 라벨.
  String _primaryLabel(_Load l) {
    if (!_graded) return '정답 확인';
    if (widget.n < _max) return '다음 →';
    if (l.exam.listening != null) return '청해 →';
    return '회차 완료';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.load;
    final n = widget.n;
    final furi = Store.instance.getSettings().furigana;
    final position = (n - _min + 1).clamp(1, _max - _min + 1);
    final rangeTotal = (_max - _min + 1).clamp(1, 999);
    final progress = position / rangeTotal;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n / $_max',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(categoryKo(l.q.category),
                style: const TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Store.instance.setSettings(Store.instance
                  .getSettings()
                  .copyWith(furigana: !furi));
              if (mounted) setState(() {});
            },
            child: Text('후리가나 ${furi ? 'ON' : 'OFF'}',
                style: TextStyle(
                  color: furi ? accentPrimary : textMuted,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE5E7EB),
            color: accentPrimary,
            minHeight: 3,
          ),
        ),
      ),
      // 하단 sticky CTA bar 가 따로 있으므로 ListView 내부 bottom 패딩은 24 만
      // (CTA bar 가 자체 SafeArea 처리).
      body: Column(
        children: [
          Expanded(
            child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (l.q.srcLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${l.q.srcLabel} · ${l.q.srcN}',
                style: const TextStyle(fontSize: 12, color: textMuted),
              ),
            ),
          // 정보 검색 같은 문제는 passage 가 등록은 돼있지만 ja 가 비어있는
          // 경우가 있음 (실제 표/도표 데이터가 stem 에 들어있음). 비어있으면
          // 빈 박스 안 보이게 스킵.
          if (l.q.passage != null &&
              l.exam.passages[l.q.passage] != null &&
              l.exam.passages[l.q.passage]!.ja.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JapaneseText(
                    text: l.exam.passages[l.q.passage]!.ja,
                    index: l.idx,
                    furigana: furi,
                    onWordTap: (e) => VocabSheet.show(
                      context,
                      entry: e,
                      kanjiKo: l.kanjiKo,
                    ),
                  ),
                  // 독해 그룹 문제는 한국어 번역을 숨김 — 진짜 독해 훈련을 위해.
                  // (어휘/문법 문제는 보조 자료로 보여줘도 됨)
                  if (l.exam.passages[l.q.passage]!.ko != null &&
                      groupOfCategory(l.q.category) !=
                          CategoryGroup.reading) ...[
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text('한국어 번역',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l.exam.passages[l.q.passage]!.ko!,
                            style: const TextStyle(
                                fontSize: 14, height: 1.6, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (l.q.stem.isNotEmpty)
            // 정보 검색 처럼 stem 안에 표/지문이 들어있는 경우는 다른 독해
            // 문제처럼 흰 박스로 감싸 시각적 일관성 확보.
            l.q.category == 'Information Retrieval'
                ? Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: JapaneseText(
                      text: formatTableStem(l.q.stem, l.q.opts),
                      index: l.idx,
                      furigana: furi,
                      underline: l.q.stemU,
                      baseStyle: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: ink,
                      ),
                      onWordTap: (e) => VocabSheet.show(
                        context,
                        entry: e,
                        kanjiKo: l.kanjiKo,
                      ),
                    ),
                  )
                : JapaneseText(
                    text: l.q.stem,
                    index: l.idx,
                    furigana: furi,
                    underline: l.q.stemU,
                    baseStyle: const TextStyle(
                      fontSize: 17,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                    ),
                    onWordTap: (e) =>
                        VocabSheet.show(context, entry: e, kanjiKo: l.kanjiKo),
                  )
          else
            const Text(
              '(빈칸 채우기 — 위 지문 참조)',
              style: TextStyle(fontSize: 14, color: textMuted),
            ),
          const SizedBox(height: 16),
          ...List.generate(l.q.opts.length, (i) {
            final picked = i == _picked;
            final isCorrect = _graded && i == l.q.correct;
            final isWrong = _graded && i == _picked && i != l.q.correct;
            Color bg = Colors.white;
            Color border = cardBorder;
            Color fg = const Color(0xFF111827);
            if (isCorrect) {
              bg = const Color(0xFFDCFCE7);
              border = const Color(0xFF15803D);
            } else if (isWrong) {
              bg = const Color(0xFFFEE2E2);
              border = const Color(0xFFB91C1C);
            } else if (picked) {
              // 선택된 옵션 — "오답" 처럼 안 보이게.
              // 옅은 핑크 bg + 또렷한 핑크 보더 + 검정 글자.
              // 텍스트가 빨갛지 않으니 에러 느낌이 사라짐.
              bg = brandSurface;
              border = brandPrimary;
              fg = ink;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _graded ? null : () => _select(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      // 보더 굵기 고정 — 선택 유무로 카드 사이즈가 밀리지 않게.
                      border: Border.all(color: border, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            )),
                        const SizedBox(width: 10),
                        Expanded(
                          child: JapaneseText(
                            text: l.q.opts[i],
                            index: l.idx,
                            furigana: furi,
                            baseStyle: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: fg,
                              fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                            ),
                            onWordTap: (e) => VocabSheet.show(
                              context,
                              entry: e,
                              kanjiKo: l.kanjiKo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // 피드백 — 채점 후에만 표시. 스크롤 영역 안에 두어 사용자가
          // CTA 누르기 전에 충분히 읽고 넘어가도록.
          if (_graded) ...[
            const SizedBox(height: 14),
            _Feedback(q: l.q, picked: _picked),
          ],
        ],
            ),
          ),
          _bottomBar(context, l, n),
        ],
      ),
    );
  }

  /// 하단 고정 액션바 — 단일 메인 CTA + 좌측 ← 이전 아이콘.
  /// Duolingo/Anki/마더텅 등 학습앱들의 공통 패턴 (sticky bottom CTA).
  Widget _bottomBar(BuildContext context, _Load l, int n) {
    final canBack = n > _min;
    return Material(
      color: cardBg,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                // ← 이전: 아이콘 전용 보조 버튼 (활성 조건에서만 보이게)
                Material(
                  color: canBack ? brandSurface : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: canBack ? () => _navigate(n - 1) : null,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: canBack ? brandPrimary : const Color(0xFFCBD5E1),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 메인 CTA — 상태에 따라 변신
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accentPrimary,
                      disabledBackgroundColor: const Color(0xFFE5E1E4),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      minimumSize: const Size(0, 52),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: _primaryAction(l),
                    child: Text(_primaryLabel(l)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  final Question q;
  final int picked;
  const _Feedback({required this.q, required this.picked});

  @override
  Widget build(BuildContext context) {
    final correct = picked == q.correct;
    final tint = correct ? okSoft : dangerSoft;
    final verdictColor = correct ? ok : danger;
    final emoji = correct ? '🎉' : '🤔';
    final verdict = correct ? '정답!' : '아쉬워요';
    final expl = (q.explKo?.isNotEmpty ?? false)
        ? q.explKo!
        : (q.expl.isNotEmpty ? q.expl : '(해설 없음)');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Text(verdict,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: verdictColor,
                  )),
              const SizedBox(width: 8),
              if (!correct)
                Text('정답 ${q.correct + 1}번',
                    style: const TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      fontWeight: FontWeight.w700,
                    )),
            ],
          ),
          const SizedBox(height: 12),
          Explanation(text: expl),
        ],
      ),
    );
  }
}
