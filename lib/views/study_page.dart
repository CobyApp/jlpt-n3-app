/// 급수별 학습 콘텐츠 페이지 — 핵심단어/표현/문법 탭.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/data_loader.dart';
import '../l10n/strings.dart';
import '../models/study.dart';
import '../state/store.dart';
import '../theme.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Future<_StudyBundle> _f;
  String _level = '';
  static const List<String> _tabTypes = ['vocab', 'expr', 'grammar'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
    _level = 'n3';
    _f = _load(_level);
    Store.instance.addListener(_onChange);
  }

  Future<_StudyBundle> _load(String lv) async {
    final results = await Future.wait([
      DataLoader.instance.loadStudy(),
      DataLoader.instance.loadKanjiKo(),
    ]);
    return _StudyBundle(
      content: results[0] as StudyContent,
      kanjiKo: results[1] as Map<String, List<String>>,
    );
  }

  void _onChange() {
    final lv = 'n3';
    if (lv != _level) {
      setState(() {
        _level = lv;
        _f = _load(lv);
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    Store.instance.removeListener(_onChange);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Store.instance.currentLanguage;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          tx('study.title', {'level': _level.toUpperCase()}),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: t('study.cards_mode'),
            icon: const Icon(Icons.style_rounded),
            onPressed: () {
              final type = _tabTypes[_tab.index];
              context.push('/study/cards/$type');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: brandPrimary,
          unselectedLabelColor: textMuted,
          indicatorColor: brandPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: t('study.tab_vocab')),
            Tab(text: t('study.tab_expr')),
            Tab(text: t('study.tab_grammar')),
          ],
        ),
      ),
      body: FutureBuilder<_StudyBundle>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(child: Text(t('study.empty')));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          return TabBarView(
            controller: _tab,
            children: [
              _VocabTab(themes: b.content.vocab, lang: lang, kanjiKo: b.kanjiKo),
              _ExprTab(items: b.content.expressions, lang: lang),
              _GrammarTab(items: b.content.grammar, lang: lang),
            ],
          );
        },
      ),
    );
  }
}

class _StudyBundle {
  final StudyContent content;
  final Map<String, List<String>> kanjiKo;
  _StudyBundle({required this.content, required this.kanjiKo});
}

// ─────────────────────────── 공통 위젯 ───────────────────────────

/// 카드 컨테이너 (공통 스타일).
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: child,
      );
}

/// 일본어 + 번역 페어 블록 (예문 등).
class _BilingualBlock extends StatelessWidget {
  final String ja;
  final String tr;
  const _BilingualBlock({required this.ja, required this.tr});

  @override
  Widget build(BuildContext context) {
    final tint = brandPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ja,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: textMuted,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── 단어 탭 ───────────────────────────

class _VocabTab extends StatelessWidget {
  final List<StudyVocabTheme> themes;
  final String lang;
  final Map<String, List<String>> kanjiKo;
  const _VocabTab({
    required this.themes,
    required this.lang,
    required this.kanjiKo,
  });

  bool _isKanji(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  /// 단어에서 한자 문자만 추출해 한국 음/뜻 lookup 결과 반환.
  /// [(漢, "음", "뜻"), ...]
  List<List<String>> _kanjiReadings(String w) {
    final out = <List<String>>[];
    final seen = <String>{};
    for (final ch in w.split('')) {
      if (!_isKanji(ch) || seen.contains(ch)) continue;
      seen.add(ch);
      final r = kanjiKo[ch];
      if (r != null && r.isNotEmpty) {
        out.add([ch, r.length > 1 ? r[1] : '', r[0]]);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) return Center(child: Text(t('study.empty')));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      itemCount: themes.length,
      itemBuilder: (c, i) {
        final th = themes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: brandPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      th.themeFor(lang),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: brandPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              ...th.items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _vocabCard(it),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _vocabCard(StudyVocabItem item) {
    final readings = _kanjiReadings(item.w);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 일본어 단어 + 후리가나
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: item.w,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              if (item.r.isNotEmpty)
                TextSpan(
                  text: '   ${item.r}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ]),
          ),
          // 한자 음/뜻 (있을 때만)
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: readings.map((r) {
                final ch = r[0];
                final hoon = r[1];
                final eum = r[2];
                return Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: ch,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: brandPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' $hoon $eum',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: textMuted,
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          // 뜻
          Text(
            item.meaningFor(lang),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.exJa.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BilingualBlock(
              ja: item.exJa,
              tr: item.exampleFor(lang),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── 표현 탭 ───────────────────────────

class _ExprTab extends StatelessWidget {
  final List<StudyExpression> items;
  final String lang;
  const _ExprTab({required this.items, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(t('study.empty')));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      itemCount: items.length,
      separatorBuilder: (_, i) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final e = items[i];
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                  text: e.ja,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2),
                ),
                if (e.r.isNotEmpty)
                  TextSpan(
                      text: '   ${e.r}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          fontWeight: FontWeight.w500)),
              ])),
              const SizedBox(height: 10),
              Text(
                e.meaningFor(lang),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (e.exJa.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BilingualBlock(ja: e.exJa, tr: e.exampleFor(lang)),
              ],
              if (e.tipFor(lang).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 15, color: brandPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.tipFor(lang),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────── 문법 탭 ───────────────────────────

class _GrammarTab extends StatelessWidget {
  final List<StudyGrammar> items;
  final String lang;
  const _GrammarTab({required this.items, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(t('study.empty')));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      itemCount: items.length,
      separatorBuilder: (_, i) => const SizedBox(height: 10),
      itemBuilder: (c, i) {
        final g = items[i];
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  g.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: brandPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                g.meaningFor(lang),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (g.exJa.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BilingualBlock(ja: g.exJa, tr: g.exampleFor(lang)),
              ],
              if (g.noteFor(lang).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        g.noteFor(lang),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
