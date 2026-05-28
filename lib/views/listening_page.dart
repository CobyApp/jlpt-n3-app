/// 청해 풀이 — 한 mondai(問題) 전체를 한 화면에 (인트로/오디오/문제들).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../data/data_loader.dart';
import '../data/vocab_match.dart';
import '../models/models.dart';
import '../state/store.dart';
import '../theme.dart';
import '../widgets/explanation.dart';
import '../widgets/japanese_text.dart';
import '../widgets/vocab_sheet.dart';

class ListeningPage extends StatefulWidget {
  final String examId;
  final int m;
  const ListeningPage({super.key, required this.examId, required this.m});

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  late Future<_Load> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void didUpdateWidget(covariant ListeningPage old) {
    super.didUpdateWidget(old);
    if (old.examId != widget.examId || old.m != widget.m) {
      _f = _load();
    }
  }

  Future<_Load> _load() async {
    final exam = await DataLoader.instance.loadExam(widget.examId);
    if (exam.listening == null) {
      throw Exception('청해 데이터가 없습니다.');
    }
    final sub = exam.listening!.subsections.firstWhere(
      (s) => s.order == widget.m,
      orElse: () => throw Exception('問題${widget.m}을 찾을 수 없습니다.'),
    );
    final vocab = await DataLoader.instance.loadVocab();
    final kanjiKo = await DataLoader.instance.loadKanjiKo();
    return _Load(exam, sub, VocabIndex.build(vocab), kanjiKo);
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _ListeningView(load: snap.data!, m: widget.m);
      },
    );
  }
}

class _Load {
  final Exam exam;
  final ListeningSubsection sub;
  final VocabIndex idx;
  final Map<String, List<String>> kanjiKo;
  _Load(this.exam, this.sub, this.idx, this.kanjiKo);
}

class _ListeningView extends StatefulWidget {
  final _Load load;
  final int m;
  const _ListeningView({required this.load, required this.m});

  @override
  State<_ListeningView> createState() => _ListeningViewState();
}

class _ListeningViewState extends State<_ListeningView> {
  late final AudioPlayer _player;
  final ScrollController _scroll = ScrollController();
  final Map<String, int> _picked = {};
  final Set<String> _graded = {};
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _showMini = false;

  /// `taba.asia/jlpt-audio/<examId>/<file>.mp3` →
  /// `assets/audio/<examId>/<file>.mp3`. Bundled locally for offline.
  String _assetPath(String raw) {
    // Strip protocol + host if present; we only need the tail after jlpt-audio/.
    final idx = raw.indexOf('jlpt-audio/');
    final tail = idx >= 0 ? raw.substring(idx + 'jlpt-audio/'.length) : raw;
    return 'assets/audio/$tail';
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _hydratePersisted();
    _setupAudio();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    // Show mini-player once user scrolls past the audio card (~220px).
    final should = _scroll.offset > 220;
    if (should != _showMini && mounted) {
      setState(() => _showMini = should);
    }
  }

  void _hydratePersisted() {
    final saved = Store.instance.getListenProgress(widget.load.exam.testId);
    for (final q in widget.load.sub.questions) {
      final rec = saved[q.id];
      if (rec != null) {
        _picked[q.id] = rec.picked;
        _graded.add(q.id);
      }
    }
  }

  Future<void> _setupAudio() async {
    try {
      await _player.setAsset(_assetPath(widget.load.sub.audioUrl));
    } catch (e) {
      // ignore — UI still works without audio
    }
    _player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.playingStream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  void _select(String qid, int i) {
    if (_graded.contains(qid)) return;
    setState(() => _picked[qid] = i);
  }

  Future<void> _submit(ListeningQuestion q) async {
    final picked = _picked[q.id];
    if (picked == null || _graded.contains(q.id)) return;
    final correct = picked == q.correct;
    await Store.instance.recordListenAnswer(
        widget.load.exam.testId, q.id, picked, correct);
    setState(() => _graded.add(q.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.load;
    final furi = Store.instance.getSettings().furigana;
    final total = l.exam.listening!.subsections.length;
    final prev = widget.m > 1 ? widget.m - 1 : null;
    final next = widget.m < total ? widget.m + 1 : null;
    final introPlain = htmlToPlain(l.sub.introHtml);

    return Theme(
      // 청해는 파란 톤으로 살짝 오버라이드.
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: listeningPrimary,
              secondary: listeningPrimary,
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('問題${l.sub.order} / $total',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              Text('聴解 · ${l.sub.englishTitle}',
                  style: const TextStyle(
                      fontSize: 11, color: listeningPrimary)),
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
                    color: furi ? listeningPrimary : textMuted,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 48 + MediaQuery.of(context).viewPadding.bottom),
              children: [
            _subnav(context, l, widget.m),
            const SizedBox(height: 14),
            if (introPlain.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: JapaneseText(
                  text: introPlain,
                  index: l.idx,
                  furigana: furi,
                  onWordTap: (e) =>
                      VocabSheet.show(context, entry: e, kanjiKo: l.kanjiKo),
                ),
              ),
            _audioCard(),
            const SizedBox(height: 18),
            ...l.sub.questions
                .map((q) => _questionCard(q, furi))
                .toList(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (prev != null) {
                        context.go('/exam/${l.exam.testId}/listen/$prev');
                      } else {
                        // m=1 → 마지막 reading 문제로
                        final readingTotal = l.exam.questions.length;
                        if (readingTotal > 0) {
                          context.go(
                              '/exam/${l.exam.testId}/q/$readingTotal');
                        } else {
                          context.go('/exam/${l.exam.testId}');
                        }
                      }
                    },
                    child: Text(prev != null ? '← 問題$prev' : '← 독해로'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: listeningPrimary),
                    onPressed: () {
                      if (next != null) {
                        context.go('/exam/${l.exam.testId}/listen/$next');
                      } else {
                        context.go('/exam/${l.exam.testId}');
                      }
                    },
                    child: Text(next != null ? '問題$next →' : '완료 · 회차로'),
                  ),
                ),
              ],
            ),
              ],
            ),
            // Sticky mini audio player — slides in once user scrolls past the
            // big audio card.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: _showMini ? 0 : -80,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: _miniPlayer(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPlayer() {
    final pos = _position;
    final dur = _duration;
    final progress = dur.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      shadowColor: const Color(0x33000000),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: listeningPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: () => _playing ? _player.pause() : _player.play(),
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: listeningPrimary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                minimumSize: const Size(34, 34),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '問題${widget.load.sub.order} · ${_fmt(pos)} / ${_fmt(dur)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: listeningPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          listeningPrimary.withValues(alpha: 0.12),
                      color: listeningPrimary,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                _scroll.animateTo(0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic);
              },
              icon: const Icon(Icons.unfold_more, size: 18),
              color: textMuted,
              tooltip: '오디오 카드로 이동',
            ),
          ],
        ),
      ),
    );
  }

  Widget _subnav(BuildContext context, _Load l, int active) {
    final subs = l.exam.listening!.subsections;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = subs[i];
          final isActive = s.order == active;
          return Material(
            color: isActive ? listeningPrimary : listeningPale,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  context.go('/exam/${l.exam.testId}/listen/${s.order}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Text('問題${s.order}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : listeningPrimary,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _audioCard() {
    final pos = _position;
    final dur = _duration;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: listeningPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: () =>
                    _playing ? _player.pause() : _player.play(),
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: listeningPrimary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  minimumSize: const Size(44, 44),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '問題${widget.load.sub.order} · ${widget.load.sub.englishTitle}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: listeningPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_fmt(pos)} / ${_fmt(dur)} · ${widget.load.sub.questions.length}문제',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              activeColor: listeningPrimary,
              inactiveColor: listeningPrimary.withValues(alpha: 0.18),
              value: dur.inMilliseconds == 0
                  ? 0
                  : pos.inMilliseconds
                      .clamp(0, dur.inMilliseconds)
                      .toDouble(),
              max: dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds.toDouble(),
              onChanged: (v) =>
                  _player.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _questionCard(ListeningQuestion q, bool furi) {
    final picked = _picked[q.id] ?? -1;
    final graded = _graded.contains(q.id);
    // Trailing-empty option trim (Quick Response has 3).
    int count = q.opts.length;
    while (count > 0 && q.opts[count - 1].trim().isEmpty) {
      count--;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: listeningPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Q${q.n}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: listeningPrimary,
                    )),
              ),
              const SizedBox(width: 8),
              Text('선택지 $count개 — 음성을 듣고 고르세요',
                  style: const TextStyle(fontSize: 11, color: textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(count, (i) {
            final isPicked = i == picked;
            final isCorrect = graded && i == q.correct;
            final isWrong = graded && i == picked && i != q.correct;
            Color bg = Colors.white;
            Color border = cardBorder;
            Color fg = const Color(0xFF111827);
            if (isCorrect) {
              bg = const Color(0xFFDCFCE7);
              border = const Color(0xFF15803D);
            } else if (isWrong) {
              bg = const Color(0xFFFEE2E2);
              border = const Color(0xFFB91C1C);
            } else if (isPicked) {
              bg = listeningPale;
              border = listeningPrimary;
              fg = listeningPrimary;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: graded ? null : () => _select(q.id, i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // 보더 굵기 고정 — 선택 유무로 카드 사이즈가 밀리지 않게.
                      border: Border.all(color: border, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            )),
                        const SizedBox(width: 8),
                        Expanded(
                          child: JapaneseText(
                            text: q.opts[i],
                            index: widget.load.idx,
                            furigana: furi,
                            baseStyle: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: fg,
                              fontWeight: isPicked
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onWordTap: (e) => VocabSheet.show(
                              context,
                              entry: e,
                              kanjiKo: widget.load.kanjiKo,
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
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (picked < 0 || graded) ? null : () => _submit(q),
              style: FilledButton.styleFrom(
                backgroundColor: listeningPrimary,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
              ),
              child: Text(graded ? '확인됨' : '정답 확인'),
            ),
          ),
          if (graded) ...[
            const SizedBox(height: 10),
            _listenFeedback(q, picked, furi),
          ],
        ],
      ),
    );
  }

  Widget _listenFeedback(ListeningQuestion q, int picked, bool furi) {
    final correct = picked == q.correct;
    final scriptPlain = htmlToPlain(q.scriptHtml);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(correct ? '✓ 정답' : '✗ 오답 (정답: ${q.correct + 1}번)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: correct
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
              )),
          if (scriptPlain.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('音声スクリプト',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: listeningPrimary,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 4),
            JapaneseText(
              text: scriptPlain,
              index: widget.load.idx,
              furigana: furi,
              baseStyle: const TextStyle(
                  fontSize: 13.5, height: 1.65, color: Color(0xFF1F2937)),
              onWordTap: (e) => VocabSheet.show(
                context,
                entry: e,
                kanjiKo: widget.load.kanjiKo,
              ),
            ),
          ],
          if (q.translationKo?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text('한국어 번역',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: listeningPrimary,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 4),
            Text(q.translationKo!,
                style: const TextStyle(fontSize: 13.5, height: 1.55)),
          ],
          if (q.explKo?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text('해설',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: listeningPrimary,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 6),
            Explanation(
              text: q.explKo!,
              labelColor: listeningPrimary,
              bodyStyle: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
