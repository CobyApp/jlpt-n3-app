/// 가장 긴 매칭 우선의 단어 분절기 — src/lib/vocab-match.ts와 동일한 알고리즘.
library;

import '../models/models.dart';

class VocabSegment {
  final String text;
  final VocabEntry? entry;
  const VocabSegment(this.text, this.entry);
}

class VocabIndex {
  final Map<String, List<VocabEntry>> byHead;
  VocabIndex(this.byHead);

  factory VocabIndex.build(List<VocabEntry> vocab) {
    final map = <String, List<VocabEntry>>{};
    for (final v in vocab) {
      if (v.w.isEmpty) continue;
      final head = v.w[0];
      (map[head] ??= <VocabEntry>[]).add(v);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.w.length.compareTo(a.w.length));
    }
    return VocabIndex(map);
  }
}

List<VocabSegment> matchVocab(String text, VocabIndex idx) {
  final out = <VocabSegment>[];
  var buf = StringBuffer();
  int i = 0;
  while (i < text.length) {
    final head = text[i];
    final candidates = idx.byHead[head];
    VocabEntry? matched;
    if (candidates != null) {
      for (final c in candidates) {
        if (i + c.w.length <= text.length &&
            text.substring(i, i + c.w.length) == c.w) {
          matched = c;
          break;
        }
      }
    }
    if (matched != null) {
      if (buf.isNotEmpty) {
        out.add(VocabSegment(buf.toString(), null));
        buf = StringBuffer();
      }
      out.add(VocabSegment(matched.w, matched));
      i += matched.w.length;
    } else {
      buf.write(head);
      i++;
    }
  }
  if (buf.isNotEmpty) out.add(VocabSegment(buf.toString(), null));
  return out;
}

/// 청해 nihonez HTML에서 ruby/태그 제거하고 평문화.
String htmlToPlain(String html) {
  if (html.isEmpty) return '';
  var s = html
      .replaceAll(RegExp(r'<rt>.*?</rt>', dotAll: true), '')
      .replaceAll(RegExp(r'</?ruby>'), '')
      .replaceAll(RegExp(r'<br\s*/?>\s*<br\s*/?>'), '\n\n')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'</(?:p|div|li|h[1-6])>'), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
