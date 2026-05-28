/// 단어 플래시카드 학습 모달.
/// - 카드를 탭 → 뜻 공개
/// - "또" / "건너뛰기" / "쉬워요" 로 채점
/// - level/seen/correct/wrong 가 자동 갱신
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/store.dart';
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
    this.title = '단어장 외우기',
    this.order = StudyOrder.weakest,
  });

  static Future<void> open(
    BuildContext context, {
    required List<VocabEntry> words,
    required Map<String, List<String>> kanjiKo,
    String title = '단어장 외우기',
    StudyOrder order = StudyOrder.weakest,
  }) {
    if (words.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyModal(
          words: words,
          kanjiKo: kanjiKo,
          title: title,
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
  late List<VocabEntry> _queue;
  int _i = 0;
  bool _revealed = false;
  final _stats = _Stats();
  static final _kanjiRe = RegExp(r'[一-龯々ヶ]');

  @override
  void initState() {
    super.initState();
    _queue = _orderWords(widget.words, widget.order);
  }

  List<VocabEntry> _orderWords(List<VocabEntry> ws, StudyOrder order) {
    if (order == StudyOrder.random) {
      final list = [...ws]..shuffle(Random());
      return list;
    }
    if (order == StudyOrder.unseen) {
      final unseen = <VocabEntry>[];
      final rest = <VocabEntry>[];
      for (final w in ws) {
        final s = Store.instance.getSrs(w.w);
        if (s.level < 0) {
          unseen.add(w);
        } else {
          rest.add(w);
        }
      }
      unseen.shuffle(Random());
      rest.shuffle(Random());
      return [...unseen, ...rest];
    }
    // weakest
    final annotated =
        ws.map((w) => (w: w, s: Store.instance.getSrs(w.w))).toList();
    annotated.sort((a, b) {
      final la = a.s.level < 0 ? -1 : a.s.level;
      final lb = b.s.level < 0 ? -1 : b.s.level;
      if (la != lb) return la.compareTo(lb);
      return a.s.lastTs.compareTo(b.s.lastTs);
    });
    return annotated.map((x) => x.w).toList();
  }

  Future<void> _act(SrsAction action) async {
    final w = _queue[_i];
    await Store.instance.recordSrs(w.w, action);
    switch (action) {
      case SrsAction.again:
        _stats.again++;
      case SrsAction.easy:
        _stats.easy++;
      case SrsAction.skip:
        _stats.skip++;
    }
    if (mounted) {
      setState(() {
        _i++;
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _queue.length;
    final done = _i >= total;
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
            Text(done ? '완료' : '${_i + 1} / $total',
                style: const TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (_i / total).clamp(0, 1),
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
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉',
                style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('학습 완료',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _statRow('쉬워요', _stats.easy, const Color(0xFF15803D)),
            _statRow('건너뜀', _stats.skip, textMuted),
            _statRow('또 보기', _stats.again, const Color(0xFFB91C1C)),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentPrimary),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('완료'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Text('$v',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }

  Widget _card() {
    final w = _queue[_i];
    final srs = Store.instance.getSrs(w.w);
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
                      Row(
                        children: [
                          if (srs.level >= 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: srs.level >= 5
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                srs.level >= 5
                                    ? '✓ 마스터'
                                    : 'Lv.${srs.level}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: srs.level >= 5
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                                  : const Text(
                                      '카드를 탭해서 뜻 보기',
                                      key: ValueKey('hint'),
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
                  child: const Text('또 보기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _act(SrsAction.skip);
                  },
                  child: const Text('건너뛰기'),
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
                  child: const Text('쉬워요'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
