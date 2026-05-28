/// 청해 카테고리 (cat:listen-X) — 11회차의 같은 mondai 타입을 한자리에.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/categories.dart';
import '../data/data_loader.dart';
import '../models/models.dart';
import '../state/store.dart';
import '../theme.dart';
import '../widgets/progress_track.dart';

class CategoryListeningPage extends StatefulWidget {
  final String slug;
  const CategoryListeningPage({super.key, required this.slug});

  @override
  State<CategoryListeningPage> createState() =>
      _CategoryListeningPageState();
}

class _CategoryListeningPageState extends State<CategoryListeningPage> {
  late Future<List<_Entry>> _entriesF;

  @override
  void initState() {
    super.initState();
    _entriesF = _loadEntries();
    Store.instance.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Store.instance.removeListener(_onChange);
    super.dispose();
  }

  Future<List<_Entry>> _loadEntries() async {
    final type = listeningTypeFromSlug(widget.slug);
    if (type == null) return [];
    final idx = await DataLoader.instance.loadIndex();
    final out = <_Entry>[];
    for (final ie in idx.exams) {
      final exam = await DataLoader.instance.loadExam(ie.id);
      final sub = exam.listening?.subsections
          .firstWhere((s) => s.type == type, orElse: () =>
              ListeningSubsection(
                order: -1,
                title: '',
                englishTitle: '',
                type: '',
                introHtml: '',
                audioUrl: '',
                questions: const [],
              ));
      if (sub == null || sub.order == -1) continue;
      out.add(_Entry(exam, sub));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final mondaiType = listeningTypeFromSlug(widget.slug);
    if (mondaiType == null) {
      return const Scaffold(body: Center(child: Text('알 수 없는 청해 카테고리입니다.')));
    }
    final categoryName = categoryKo(mondaiType);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('청해 모음',
            style: TextStyle(fontSize: 14, color: textMuted)),
      ),
      body: FutureBuilder<List<_Entry>>(
        future: _entriesF,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data!;
          final totalQ = entries.fold<int>(0, (s, e) => s + e.sub.questions.length);
          int answered = 0, correct = 0;
          for (final e in entries) {
            final prog = Store.instance.getListenProgress(e.exam.testId);
            for (final q in e.sub.questions) {
              final r = prog[q.id];
              if (r != null) {
                answered++;
                if (r.correct) correct++;
              }
            }
          }
          final accuracy =
              answered == 0 ? 0 : ((correct / answered) * 100).round();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: listeningPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '11회차에서 같은 유형의 청해 mondai를 모아서 풀어보세요. ${entries.length}회차 · $totalQ문제${answered > 0 ? ' · 정답률 $accuracy%' : ''}',
                style: const TextStyle(fontSize: 13, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 18),
              ...entries.map((e) {
                final prog = Store.instance.getListenProgress(e.exam.testId);
                final ans = e.sub.questions.where((q) => prog[q.id] != null).length;
                final corr = e.sub.questions
                    .where((q) => prog[q.id]?.correct == true)
                    .length;
                final pct =
                    e.sub.questions.isEmpty ? 0 : (ans / e.sub.questions.length);
                final acc =
                    ans == 0 ? 0 : ((corr / ans) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context
                          .push('/exam/${e.exam.testId}/listen/${e.sub.order}'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: listeningPrimary.withValues(alpha: 0.18)),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: listeningPale,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '청해 問題${e.sub.order}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: listeningPrimary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text('${e.sub.questions.length}문제',
                                    style: const TextStyle(
                                        fontSize: 11, color: textMuted)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              shortTitle(e.exam.title),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25),
                            ),
                            const SizedBox(height: 12),
                            ProgressTrack(
                                progress: pct.toDouble(),
                                color: listeningPrimary),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('$ans/${e.sub.questions.length} 완료',
                                    style: const TextStyle(
                                        fontSize: 11, color: textMuted)),
                                const Spacer(),
                                Text('정답률 $acc%',
                                    style: const TextStyle(
                                        fontSize: 11, color: textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _Entry {
  final Exam exam;
  final ListeningSubsection sub;
  _Entry(this.exam, this.sub);
}
