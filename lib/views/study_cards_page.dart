/// 학습 카드 — 단어/표현/문법을 한 장씩 넘기며 학습 (Tap to flip).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/data_loader.dart';
import '../l10n/strings.dart';
import '../models/study.dart';
import '../state/store.dart';
import '../theme.dart';

class StudyCardsPage extends StatefulWidget {
  /// 'vocab' | 'expr' | 'grammar'
  final String type;
  const StudyCardsPage({super.key, required this.type});

  @override
  State<StudyCardsPage> createState() => _StudyCardsPageState();
}

class _StudyCardsPageState extends State<StudyCardsPage> {
  late Future<_Bundle> _f;
  String _level = '';
  final PageController _pc = PageController();
  int _idx = 0;
  bool _shuffled = false;
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    _level = 'n3';
    _f = _load(_level);
    _order = [];
  }

  Future<_Bundle> _load(String lv) async {
    final results = await Future.wait([
      DataLoader.instance.loadStudy(),
      DataLoader.instance.loadKanjiKo(),
    ]);
    final c = results[0] as StudyContent;
    final kk = results[1] as Map<String, List<String>>;
    final cards = <_Card>[];
    if (widget.type == 'vocab') {
      for (final th in c.vocab) {
        for (final it in th.items) {
          cards.add(_Card.fromVocab(it, th));
        }
      }
    } else if (widget.type == 'expr') {
      for (final e in c.expressions) {
        cards.add(_Card.fromExpr(e));
      }
    } else if (widget.type == 'grammar') {
      for (final g in c.grammar) {
        cards.add(_Card.fromGrammar(g));
      }
    }
    if (_order.length != cards.length) {
      _order = List.generate(cards.length, (i) => i);
    }
    return _Bundle(cards: cards, kanjiKo: kk);
  }

  void _shuffle(int n) {
    final list = List.generate(n, (i) => i);
    list.shuffle(Random());
    setState(() {
      _order = list;
      _shuffled = true;
      _idx = 0;
    });
    _pc.jumpToPage(0);
  }

  void _reset(int n) {
    setState(() {
      _order = List.generate(n, (i) => i);
      _shuffled = false;
      _idx = 0;
    });
    _pc.jumpToPage(0);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Store.instance.currentLanguage;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/study'),
        ),
        title: Text(
          _titleFor(widget.type),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<_Bundle>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          if (b.cards.isEmpty) {
            return Center(child: Text(t('study.empty')));
          }
          final total = b.cards.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_idx + 1) / total,
                          minHeight: 6,
                          backgroundColor:
                              brandPrimary.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(brandPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${_idx + 1} / $total',
                        style: const TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _idx = i),
                  itemBuilder: (c, i) {
                    final idx = _order[i];
                    return _FlipCard(
                      card: b.cards[idx],
                      lang: lang,
                      kanjiKo: b.kanjiKo,
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 4, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
                child: Row(
                  children: [
                    _navBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: _idx > 0
                          ? () => _pc.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _shuffled ? _reset(total) : _shuffle(total),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              brandPrimary.withValues(alpha: 0.1),
                          foregroundColor: brandPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_shuffled ? Icons.sort_rounded : Icons.shuffle_rounded,
                                size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _shuffled
                                  ? t('cards.reset')
                                  : t('cards.shuffle'),
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _navBtn(
                      icon: Icons.arrow_forward_rounded,
                      onTap: _idx < total - 1
                          ? () => _pc.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _navBtn({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? Colors.white
          : Colors.white.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: brandPrimary.withValues(alpha: enabled ? 0.25 : 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: enabled
                ? brandPrimary
                : brandPrimary.withValues(alpha: 0.3),
            size: 20,
          ),
        ),
      ),
    );
  }

  String _titleFor(String type) {
    switch (type) {
      case 'vocab':
        return t('study.tab_vocab');
      case 'expr':
        return t('study.tab_expr');
      case 'grammar':
        return t('study.tab_grammar');
      default:
        return t('study.title');
    }
  }
}

class _Bundle {
  final List<_Card> cards;
  final Map<String, List<String>> kanjiKo;
  _Bundle({required this.cards, required this.kanjiKo});
}

/// 카드 한 장의 데이터 — 단어/표현/문법 공통.
class _Card {
  /// 'vocab' | 'expr' | 'grammar'
  final String kind;

  /// 앞면 표시: 일본어 단어·표현·문법 타이틀
  final String front;

  /// 앞면 부제 (후리가나 등)
  final String frontSub;

  /// 뒷면 뜻
  final String meaningKo, meaningEn, meaningZh;

  /// 예문 (일본어/번역)
  final String exJa, exKo, exEn, exZh;

  /// 보조 정보 (vocab: 테마 / expr: tip / grammar: note)
  final String supplKo, supplEn, supplZh;

  _Card({
    required this.kind,
    required this.front,
    required this.frontSub,
    required this.meaningKo,
    required this.meaningEn,
    required this.meaningZh,
    required this.exJa,
    required this.exKo,
    required this.exEn,
    required this.exZh,
    required this.supplKo,
    required this.supplEn,
    required this.supplZh,
  });

  factory _Card.fromVocab(StudyVocabItem v, StudyVocabTheme th) => _Card(
        kind: 'vocab',
        front: v.w,
        frontSub: v.r,
        meaningKo: v.ko,
        meaningEn: v.en,
        meaningZh: v.zh,
        exJa: v.exJa,
        exKo: v.exKo,
        exEn: v.exEn,
        exZh: v.exZh,
        supplKo: th.themeKo,
        supplEn: th.themeEn,
        supplZh: th.themeZh,
      );

  factory _Card.fromExpr(StudyExpression e) => _Card(
        kind: 'expr',
        front: e.ja,
        frontSub: e.r,
        meaningKo: e.ko,
        meaningEn: e.en,
        meaningZh: e.zh,
        exJa: e.exJa,
        exKo: e.exKo,
        exEn: e.exEn,
        exZh: e.exZh,
        supplKo: e.tipKo,
        supplEn: e.tipEn,
        supplZh: e.tipZh,
      );

  factory _Card.fromGrammar(StudyGrammar g) => _Card(
        kind: 'grammar',
        front: g.title,
        frontSub: '',
        meaningKo: g.meaningKo,
        meaningEn: g.meaningEn,
        meaningZh: g.meaningZh,
        exJa: g.exJa,
        exKo: g.exKo,
        exEn: g.exEn,
        exZh: g.exZh,
        supplKo: g.noteKo,
        supplEn: g.noteEn,
        supplZh: g.noteZh,
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

  String supplFor(String lang) {
    if (lang == 'en' && supplEn.isNotEmpty) return supplEn;
    if (lang == 'zh' && supplZh.isNotEmpty) return supplZh;
    return supplKo;
  }
}

class _FlipCard extends StatefulWidget {
  final _Card card;
  final String lang;
  final Map<String, List<String>> kanjiKo;
  const _FlipCard({
    required this.card,
    required this.lang,
    required this.kanjiKo,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  bool _back = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant _FlipCard old) {
    super.didUpdateWidget(old);
    if (old.card.front != widget.card.front) {
      // 새 카드로 이동 → 앞면으로 초기화
      _ac.value = 0;
      _back = false;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _flip() {
    if (_ac.isAnimating) return;
    setState(() => _back = !_back);
    if (_back) {
      _ac.forward();
    } else {
      _ac.reverse();
    }
  }

  bool _isKanji(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  List<List<String>> _kanjiReadings(String w) {
    final out = <List<String>>[];
    final seen = <String>{};
    for (final ch in w.split('')) {
      if (!_isKanji(ch) || seen.contains(ch)) continue;
      seen.add(ch);
      final r = widget.kanjiKo[ch];
      if (r != null && r.isNotEmpty) {
        out.add([ch, r.length > 1 ? r[1] : '', r[0]]);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value; // 0..1
            final angle = t * pi;
            final showBack = t > 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _backFace(),
                    )
                  : _frontFace(),
            );
          },
        ),
      ),
    );
  }

  Widget _frontFace() {
    final c = widget.card;
    final readings = c.kind == 'vocab' ? _kanjiReadings(c.front) : const <List<String>>[];
    final suppl = c.supplFor(widget.lang);
    return _cardShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 종류 + 보조 라벨 (테마/주제 등)
            if (suppl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(suppl,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: brandPrimary)),
                ),
              ),
            Text(
              c.front,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: c.kind == 'grammar' ? 28 : 36,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: c.kind == 'grammar' ? brandPrimary : Colors.black,
              ),
            ),
            if (c.frontSub.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(c.frontSub,
                  style: const TextStyle(
                      fontSize: 15,
                      color: textMuted,
                      fontWeight: FontWeight.w500)),
            ],
            if (readings.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: readings.map((r) {
                  return Text.rich(TextSpan(children: [
                    TextSpan(
                      text: r[0],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: brandPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' ${r[1]} ${r[2]}',
                      style: const TextStyle(
                          fontSize: 12, color: textMuted),
                    ),
                  ]));
                }).toList(),
              ),
            ],
            const SizedBox(height: 28),
            Text(t('cards.tap_to_flip'),
                style: const TextStyle(
                    fontSize: 11.5, color: textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _backFace() {
    final c = widget.card;
    return _cardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.front,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            if (c.frontSub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(c.frontSub,
                    style: const TextStyle(
                        fontSize: 12, color: textMuted)),
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: brandPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.meaningFor(widget.lang),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            if (c.exJa.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(t('study.section_example'),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: brandPrimary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(c.exJa,
                  style: const TextStyle(
                      fontSize: 14, height: 1.55,
                      fontWeight: FontWeight.w600)),
              if (c.exampleFor(widget.lang).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(c.exampleFor(widget.lang),
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          height: 1.5)),
                ),
            ],
            const Spacer(),
            Center(
              child: Text(t('cards.tap_to_flip'),
                  style: const TextStyle(
                      fontSize: 11.5, color: textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
