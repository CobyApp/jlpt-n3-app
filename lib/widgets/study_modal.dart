/// 단어 플래시카드 학습 모달.
/// - 카드를 탭 → 뜻 공개
/// - "또" / "건너뛰기" / "쉬워요" 로 채점
/// - level/seen/correct/wrong 가 자동 갱신
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme.dart';

enum StudyOrder { random, weakest, unseen }

class StudyModal extends StatefulWidget {
  final List<VocabEntry> words;
  final Map<String, List<String>> kanjiKo;
  final String title;
  final StudyOrder order;
  const StudyModal({
    super.key,
    required this.words,
    required this.kanjiKo,
    this.title = '',
    this.order = StudyOrder.weakest,
  });

  static Future<void> open(
    BuildContext context, {
    required List<VocabEntry> words,
    required Map<String, List<String>> kanjiKo,
    String? title,
    StudyOrder order = StudyOrder.weakest,
  }) {
    if (words.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyModal(
          words: words,
          kanjiKo: kanjiKo,
          title: title ?? t('sm.session_default'),
          order: order,
        ),
      ),
    );
  }

  @override
  State<StudyModal> createState() => _StudyModalState();
}

class _Stats {
  int easy = 0;
  int again = 0;
  int skip = 0;
}

class _StudyModalState extends State<StudyModal>
    with SingleTickerProviderStateMixin {
  /// 처음 출제 순서 (원본). 결과 화면에서 헷갈렸던 단어 표시에 사용.
  late List<VocabEntry> _initialOrder;
  /// 남아있는 학습 큐 (모르겠다고 한 단어는 뒤로 재투입).
  late List<VocabEntry> _queue;
  /// 단어별 "또" 누른 횟수 — 결과 화면 정렬용.
  final Map<String, int> _againCount = {};
  bool _revealed = false;
  final _stats = _Stats();
  static final _kanjiRe = RegExp(r'[一-龯々ヶ]');

  @override
  void initState() {
    super.initState();
    _initialOrder = _orderWords(widget.words, widget.order);
    _queue = [..._initialOrder];
  }

  void _restart() {
    setState(() {
      _againCount.clear();
      _stats.easy = 0;
      _stats.again = 0;
      _stats.skip = 0;
      _queue = [..._initialOrder];
      _revealed = false;
    });
  }

  List<VocabEntry> _orderWords(List<VocabEntry> ws, StudyOrder order) {
    // SRS 저장 안 함 → 모든 모드를 random 으로 통일.
    final list = [...ws]..shuffle(Random());
    return list;
  }

  void _act(SrsAction action) {
    if (_queue.isEmpty) return;
    final w = _queue.removeAt(0);
    switch (action) {
      case SrsAction.again:
        _stats.again++;
        _againCount[w.w] = (_againCount[w.w] ?? 0) + 1;
        _queue.add(w);
      case SrsAction.easy:
        _stats.easy++;
      case SrsAction.skip:
        _stats.skip++;
        _queue.add(w);
    }
    if (mounted) {
      setState(() {
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _initialOrder.length;
    final remaining = _queue.length;
    final done = remaining == 0;
    // 진행도: 완료한 카드 비율 (easy 누른 횟수 / 전체)
    final progress = total == 0 ? 0.0 : (_stats.easy / total).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            Text(done
                ? t('exam.done')
                : tx('sm.remaining', {'n': remaining}),
                style: const TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
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
      // 홈인디케이터 영역까지 안전하게 패딩 확보.
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: done ? _finished() : _card(),
      ),
    );
  }

  Widget _finished() {
    // 헷갈렸던 단어 = _againCount > 0. 원본 순서 유지하면서 횟수 내림차순.
    final confused = _initialOrder
        .where((w) => (_againCount[w.w] ?? 0) > 0)
        .toList()
      ..sort((a, b) =>
          (_againCount[b.w] ?? 0).compareTo(_againCount[a.w] ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const SizedBox(height: 8),
        const Center(child: Text('🎉', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 8),
        Center(
          child: Text(t('sm.done_title'),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(t('sm.done_subtitle'),
              style: const TextStyle(fontSize: 12, color: textMuted)),
        ),
        const SizedBox(height: 22),
        // 통계 카드
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: _statCell(
                  label: t('sm.easy'),
                  value: '${_stats.easy}',
                  color: const Color(0xFF15803D),
                ),
              ),
              Container(width: 1, height: 36, color: cardBorder),
              Expanded(
                child: _statCell(
                  label: t('sm.again'),
                  value: '${_stats.again}',
                  color: const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // 헷갈렸던 단어
        Row(
          children: [
            Text(t('sm.confused_title'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text('${confused.length}',
                style: const TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        if (confused.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF15803D), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t('sm.confused_empty'),
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else
          ...confused.map((w) {
            final n = _againCount[w.w] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                            text: w.w,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                          if (w.r.isNotEmpty)
                            TextSpan(
                                text: '  ${w.r}',
                                style: const TextStyle(
                                    fontSize: 11, color: textMuted)),
                        ])),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            (w.mKo?.isNotEmpty == true)
                                ? w.mKo!
                                : (w.m.isEmpty ? '—' : w.m),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tx('sm.again_n', {'n': n}),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB91C1C)),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _restart,
                child: Text(t('sm.restart')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accentPrimary),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('exam.done')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCell({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: textMuted)),
      ],
    );
  }

  Widget _card() {
    final w = _queue.first;
    final hanjas = <(String, String, String)>[];
    for (final ch in w.w.split('')) {
      if (!_kanjiRe.hasMatch(ch)) continue;
      final v = widget.kanjiKo[ch];
      if (v == null) continue;
      hanjas.add((ch, v.isNotEmpty ? v[0] : '', v.length > 1 ? v[1] : ''));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              behavior: HitTestBehavior.opaque,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey('${w.w}/$_revealed'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              w.w,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _revealed ? (w.r.isEmpty ? '—' : w.r) : '???',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: _revealed
                                    ? textMuted
                                    : const Color(0xFFD1D5DB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _revealed
                                  ? Text(
                                      (w.mKo?.isNotEmpty == true)
                                          ? w.mKo!
                                          : (w.m.isEmpty ? '(의미 없음)' : w.m),
                                      key: const ValueKey('m'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        height: 1.5,
                                      ),
                                    )
                                  : Text(
                                      t('sm.tap_to_reveal'),
                                      key: const ValueKey('hint'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textMuted,
                                      ),
                                    ),
                            ),
                            if (_revealed && hanjas.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: hanjas
                                    .map((h) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(h.$1,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(width: 6),
                                              Text(h.$2,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Color(0xFF1D4ED8),
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(width: 4),
                                              Text(h.$3,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: textMuted)),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  onPressed: () {
                    if (!_revealed) setState(() => _revealed = true);
                    _act(SrsAction.again);
                  },
                  child: Text(t('sm.again')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                  ),
                  onPressed: () {
                    if (!_revealed) setState(() => _revealed = true);
                    _act(SrsAction.easy);
                  },
                  child: Text(t('sm.easy')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
