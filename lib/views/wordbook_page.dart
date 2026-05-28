/// 단어장 — 저장된 단어 그리드.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/data_loader.dart';
import '../models/models.dart';
import '../state/store.dart';
import '../theme.dart';
import '../widgets/study_modal.dart';

enum _SortKey { recent, oldest, len, reading }

class WordbookPage extends StatefulWidget {
  const WordbookPage({super.key});

  @override
  State<WordbookPage> createState() => _WordbookPageState();
}

class _WordbookPageState extends State<WordbookPage> {
  late Future<_Bundle> _f;
  _SortKey _sort = _SortKey.recent;
  static final _kanjiRe = RegExp(r'[一-龯々ヶ]');

  @override
  void initState() {
    super.initState();
    _f = _load();
    Store.instance.addListener(_on);
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Store.instance.removeListener(_on);
    super.dispose();
  }

  Future<_Bundle> _load() async {
    final v = await DataLoader.instance.loadVocab();
    final k = await DataLoader.instance.loadKanjiKo();
    final map = {for (final e in v) e.w: e};
    return _Bundle(map, k);
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
        title: const Text('단어장',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<_Bundle>(
        future: _f,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(snap.data!);
        },
      ),
    );
  }

  Widget _buildBody(_Bundle b) {
    final wb = Store.instance.getWordbook();
    final list = wb.map((e) {
      final v = b.vocab[e.w];
      return _Item(e.w, e.ts, v?.r ?? '', v?.mKo ?? v?.m ?? '');
    }).toList();
    _applySort(list);

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('아직 저장한 단어가 없어요',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                '문제 풀면서 본문의 단어를 탭하고\n★ 버튼으로 단어장에 담아보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accentPrimary),
                onPressed: () => context.go('/'),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accentPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('외우기 시작',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              onPressed: list.isEmpty
                  ? null
                  : () {
                      final entries = list
                          .map((it) => b.vocab[it.w])
                          .whereType<VocabEntry>()
                          .toList();
                      StudyModal.open(
                        context,
                        words: entries,
                        kanjiKo: b.kanjiKo,
                        title: '단어장 외우기',
                      );
                    },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text('${list.length}개 단어 저장됨',
                  style: const TextStyle(
                      fontSize: 13, color: textMuted)),
              const Spacer(),
              DropdownButton<_SortKey>(
                value: _sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                      value: _SortKey.recent, child: Text('최근 추가순')),
                  DropdownMenuItem(
                      value: _SortKey.oldest, child: Text('오래된순')),
                  DropdownMenuItem(
                      value: _SortKey.len, child: Text('긴 단어순')),
                  DropdownMenuItem(
                      value: _SortKey.reading, child: Text('가나순')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                },
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('단어장 비우기'),
                      content:
                          const Text('단어장의 모든 단어를 비울까요?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(false),
                            child: const Text('취소')),
                        FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('비우기')),
                      ],
                    ),
                  );
                  if (ok == true) await Store.instance.clearWordbook();
                },
                child: const Text('전체 비우기'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, 48 + MediaQuery.of(context).viewPadding.bottom),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final it = list[i];
              return _card(it, b.kanjiKo);
            },
          ),
        ),
      ],
    );
  }

  Widget _card(_Item it, Map<String, List<String>> kanjiKo) {
    final hanjas = <(String, String, String)>[];
    for (final ch in it.w.split('')) {
      if (!_kanjiRe.hasMatch(ch)) continue;
      final v = kanjiKo[ch];
      if (v == null) continue;
      hanjas.add((ch, v.isNotEmpty ? v[0] : '', v.length > 1 ? v[1] : ''));
    }
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
                child: Text(it.w,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: () async {
                  await Store.instance.removeFromWordbook(it.w);
                },
                child: const Icon(Icons.close, size: 18, color: textMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(it.r.isEmpty ? '—' : it.r,
              style: const TextStyle(
                  fontSize: 12, color: textMuted)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              it.m.isEmpty ? '(의미 없음)' : it.m,
              style: const TextStyle(fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hanjas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: hanjas
                  .map((h) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${h.$1} ${h.$2}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1D4ED8))),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _applySort(List<_Item> arr) {
    switch (_sort) {
      case _SortKey.recent:
        arr.sort((a, b) => b.ts.compareTo(a.ts));
      case _SortKey.oldest:
        arr.sort((a, b) => a.ts.compareTo(b.ts));
      case _SortKey.len:
        arr.sort((a, b) {
          final c = b.w.length.compareTo(a.w.length);
          return c != 0 ? c : b.ts.compareTo(a.ts);
        });
      case _SortKey.reading:
        arr.sort((a, b) => a.r.compareTo(b.r));
    }
  }
}

class _Bundle {
  final Map<String, VocabEntry> vocab;
  final Map<String, List<String>> kanjiKo;
  _Bundle(this.vocab, this.kanjiKo);
}

class _Item {
  final String w;
  final int ts;
  final String r;
  final String m;
  _Item(this.w, this.ts, this.r, this.m);
}
