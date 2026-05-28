/// 단어 popover 대용 — 바텀시트로 단어 상세 + ★ 토글.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/store.dart';

class VocabSheet extends StatefulWidget {
  final VocabEntry entry;
  final Map<String, List<String>> kanjiKo;
  const VocabSheet({super.key, required this.entry, required this.kanjiKo});

  @override
  State<VocabSheet> createState() => _VocabSheetState();

  static Future<void> show(
    BuildContext context, {
    required VocabEntry entry,
    required Map<String, List<String>> kanjiKo,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VocabSheet(entry: entry, kanjiKo: kanjiKo),
    );
  }
}

class _VocabSheetState extends State<VocabSheet> {
  static final _kanjiRe = RegExp(r'[一-龯々ヶ]');

  @override
  Widget build(BuildContext context) {
    final saved = Store.instance.isInWordbook(widget.entry.w);
    final hanja = _hanjaRows(widget.entry.w);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.w,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.entry.r.isEmpty ? '—' : widget.entry.r,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Store.instance.toggleWordbook(widget.entry.w);
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    saved ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 32,
                    color: saved
                        ? const Color(0xFFEAB308)
                        : const Color(0xFF9CA3AF),
                  ),
                  tooltip: saved ? '단어장에서 제거' : '단어장에 추가',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.entry.mKo?.isNotEmpty == true
                  ? widget.entry.mKo!
                  : widget.entry.m.isNotEmpty
                      ? widget.entry.m
                      : '(의미 없음)',
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
            if (hanja.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                '한자 풀이',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hanja
                    .map((h) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                h.$1,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.$2,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    h.$3,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// (char, on, kun) tuples
  List<(String, String, String)> _hanjaRows(String word) {
    final out = <(String, String, String)>[];
    for (final ch in word.split('')) {
      if (!_kanjiRe.hasMatch(ch)) continue;
      final v = widget.kanjiKo[ch];
      if (v == null) continue;
      out.add((ch, v.isNotEmpty ? v[0] : '', v.length > 1 ? v[1] : ''));
    }
    return out;
  }
}
