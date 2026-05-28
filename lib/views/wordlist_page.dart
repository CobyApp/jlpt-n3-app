/// 회차 단어 미리보기 — 선택된 영역(섹션)에 등장하는 단어들.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/categories.dart';
import '../data/data_loader.dart';
import '../data/vocab_match.dart';
import '../models/models.dart';
import '../state/store.dart';
import '../theme.dart';
import '../widgets/study_modal.dart';

enum _SortKey { freq, len, reading }

class WordlistPage extends StatefulWidget {
  final String examId;
  final List<String>? sections;
  const WordlistPage({super.key, required this.examId, this.sections});

  @override
  State<WordlistPage> createState() => _WordlistPageState();
}

class _WordlistPageState extends State<WordlistPage> {
  late Future<_Load> _f;
  final Set<String> _active = {};
  _SortKey _sort = _SortKey.freq;
  Map<String, List<String>> _kanjiKo = const {};

  @override
  void initState() {
    super.initState();
    if (widget.sections != null) _active.addAll(widget.sections!);
    _f = _load();
    Store.instance.addListener(_on);
    DataLoader.instance.loadKanjiKo().then((m) {
      if (mounted) setState(() => _kanjiKo = m);
    });
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Store.instance.removeListener(_on);
    super.dispose();
  }

  Future<_Load> _load() async {
    final exam = await DataLoader.instance.loadExam(widget.examId);
    final vocab = await DataLoader.instance.loadVocab();
    final idx = VocabIndex.build(vocab);
    return _Load(exam, vocab, idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('단어 미리 학습',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<_Load>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(context, snap.data!);
        },
      ),
    );
  }

  // Group reading questions into sections (same as exam page).
  List<_RSection> _sections(Exam exam) {
    final isCat = exam.testId.startsWith('cat:');
    final keyOf = isCat
        ? (Question q) => q.srcLabel ?? ''
        : (Question q) => q.category;
    final out = <_RSection>[];
    for (final q in exam.questions) {
      final k = keyOf(q);
      if (out.isNotEmpty && out.last.key == k) {
        out.last.to = q.n;
      } else {
        out.add(_RSection(k, q.n, q.n, out.length));
      }
    }
    return out;
  }

  // For each reading question / listening question, vocab set + freq counter.
  _PerQ _computePerQ(_Load l) {
    final perQ = <int, Set<String>>{};
    final perLQ = <String, Set<String>>{};
    final byW = <String, VocabEntry>{};
    final freq = <String, int>{};

    for (final q in l.exam.questions) {
      final set = <String>{};
      final texts = <String>[];
      if (q.passage != null && l.exam.passages[q.passage] != null) {
        texts.add(l.exam.passages[q.passage]!.ja);
      }
      if (q.stem.isNotEmpty) texts.add(q.stem);
      texts.addAll(q.opts);
      for (final t in texts) {
        for (final seg in matchVocab(t, l.idx)) {
          if (seg.entry == null) continue;
          final w = seg.entry!.w;
          set.add(w);
          byW.putIfAbsent(w, () => seg.entry!);
        }
      }
      perQ[q.n] = set;
      for (final w in set) freq[w] = (freq[w] ?? 0) + 1;
    }

    if (l.exam.listening != null) {
      for (final sub in l.exam.listening!.subsections) {
        for (final q in sub.questions) {
          final set = <String>{};
          final texts = <String>[...q.opts];
          final scriptPlain = htmlToPlain(q.scriptHtml);
          if (scriptPlain.isNotEmpty) texts.add(scriptPlain);
          for (final t in texts) {
            for (final seg in matchVocab(t, l.idx)) {
              if (seg.entry == null) continue;
              final w = seg.entry!.w;
              set.add(w);
              byW.putIfAbsent(w, () => seg.entry!);
            }
          }
          perLQ[q.id] = set;
          for (final w in set) freq[w] = (freq[w] ?? 0) + 1;
        }
      }
    }
    return _PerQ(perQ, perLQ, byW, freq);
  }

  Widget _buildBody(BuildContext context, _Load l) {
    final readingSections = _sections(l.exam);
    final per = _computePerQ(l);
    final listenSubs = l.exam.listening?.subsections ?? const <ListeningSubsection>[];

    // Compute filtered words
    final wordSet = <String>{};
    final isAll = _active.isEmpty;
    final keyOf = l.exam.testId.startsWith('cat:')
        ? (Question q) => q.srcLabel ?? ''
        : (Question q) => q.category;
    for (final q in l.exam.questions) {
      if (!isAll && !_active.contains(keyOf(q))) continue;
      final set = per.perQ[q.n] ?? const <String>{};
      wordSet.addAll(set);
    }
    for (final sub in listenSubs) {
      final key = 'listen:${sub.order}';
      if (!isAll && !_active.contains(key)) continue;
      for (final q in sub.questions) {
        wordSet.addAll(per.perLQ[q.id] ?? const <String>{});
      }
    }
    final words = wordSet
        .map((w) => per.byW[w])
        .whereType<VocabEntry>()
        .toList();
    _applySort(words, per.freq);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _tab('all', '전체', isAll, () {
                setState(_active.clear);
              }),
              ...readingSections.map((s) {
                final active = _active.contains(s.key);
                final label = l.exam.testId.startsWith('cat:')
                    ? s.key
                    : categoryKo(s.key);
                return _tab(s.key, label, active, () {
                  setState(() {
                    if (active) {
                      _active.remove(s.key);
                    } else {
                      _active.add(s.key);
                    }
                  });
                });
              }),
              ...listenSubs.map((sub) {
                final key = 'listen:${sub.order}';
                final active = _active.contains(key);
                final label =
                    '청해 ${listeningShortKo[sub.type] ?? '問題${sub.order}'}';
                return _tab(key, label, active, () {
                  setState(() {
                    if (active) {
                      _active.remove(key);
                    } else {
                      _active.add(key);
                    }
                  });
                }, isListen: true);
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Text('${words.length}개 단어',
                  style: const TextStyle(
                      fontSize: 13, color: textMuted)),
              const Spacer(),
              TextButton.icon(
                onPressed: words.isEmpty
                    ? null
                    : () => StudyModal.open(
                          context,
                          words: words,
                          kanjiKo: _kanjiKo,
                          title: '${shortTitle(l.exam.title)} 외우기',
                        ),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('외우기'),
              ),
              DropdownButton<_SortKey>(
                value: _sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                      value: _SortKey.freq, child: Text('출현 빈도순')),
                  DropdownMenuItem(
                      value: _SortKey.len, child: Text('긴 단어순')),
                  DropdownMenuItem(
                      value: _SortKey.reading, child: Text('가나순')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: words.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '해당 범위에 매칭된 단어가 없어요.',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                      16, 4, 16, 48 + MediaQuery.of(context).viewPadding.bottom),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: words.length,
                  itemBuilder: (_, i) =>
                      _wordCard(words[i], per.freq[words[i].w] ?? 0),
                ),
        ),
      ],
    );
  }

  Widget _tab(String key, String label, bool active, VoidCallback onTap,
      {bool isListen = false}) {
    final color = isListen ? listeningPrimary : accentPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // Center 로 감싸서 horizontal ListView 의 cross-axis 안에서 수직 정렬.
      child: Center(
        child: Material(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? color : cardBorder),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordCard(VocabEntry e, int freq) {
    final saved = Store.instance.isInWordbook(e.w);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.w,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () async {
                  await Store.instance.toggleWordbook(e.w);
                },
                child: Icon(
                  saved ? Icons.star : Icons.star_border,
                  size: 22,
                  color: saved
                      ? const Color(0xFFEAB308)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(e.r.isEmpty ? '—' : e.r,
              style: const TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              (e.mKo?.isNotEmpty == true) ? e.mKo! : (e.m.isEmpty ? '(의미 없음)' : e.m),
              style: const TextStyle(fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Text('$freq개 문제 등장',
              style: const TextStyle(fontSize: 11, color: textMuted)),
        ],
      ),
    );
  }

  void _applySort(List<VocabEntry> words, Map<String, int> freq) {
    switch (_sort) {
      case _SortKey.freq:
        words.sort((a, b) {
          final c = (freq[b.w] ?? 0).compareTo(freq[a.w] ?? 0);
          return c != 0 ? c : a.w.compareTo(b.w);
        });
      case _SortKey.len:
        words.sort((a, b) {
          final c = b.w.length.compareTo(a.w.length);
          return c != 0 ? c : a.w.compareTo(b.w);
        });
      case _SortKey.reading:
        words.sort((a, b) => a.r.compareTo(b.r));
    }
  }
}

class _Load {
  final Exam exam;
  final List<VocabEntry> vocab;
  final VocabIndex idx;
  _Load(this.exam, this.vocab, this.idx);
}

class _RSection {
  final String key;
  final int from;
  int to;
  final int idx;
  _RSection(this.key, this.from, this.to, this.idx);
}

class _PerQ {
  final Map<int, Set<String>> perQ;
  final Map<String, Set<String>> perLQ;
  final Map<String, VocabEntry> byW;
  final Map<String, int> freq;
  _PerQ(this.perQ, this.perLQ, this.byW, this.freq);
}
