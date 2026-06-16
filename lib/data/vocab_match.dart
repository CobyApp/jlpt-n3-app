/// 가장 긴 매칭 우선의 단어 분절기 + 동사/형용사 활용형 환원(deinflection).
///
/// 활용형(思い出した, 高くて 등)은 사전 표제어(기본형)와 표면형이 다르다.
/// 따라서 표면형 매칭이 실패하면 어미를 환원해 기본형을 찾고, 화면에는 표면형을
/// 그대로 보여주되 탭/단어장 저장은 기본형 entry 로 연결한다.
library;

import '../models/models.dart';

class VocabSegment {
  /// 화면에 그대로 표시할 표면 텍스트 (활용형이면 활용된 형태).
  final String text;

  /// 매칭된 사전 entry (기본형). null = 비매칭 평문.
  final VocabEntry? entry;
  const VocabSegment(this.text, this.entry);
}

class VocabIndex {
  final Map<String, List<VocabEntry>> byHead;
  final Map<String, VocabEntry> byWord;
  VocabIndex(this.byHead, this.byWord);

  factory VocabIndex.build(List<VocabEntry> vocab) {
    final map = <String, List<VocabEntry>>{};
    final byWord = <String, VocabEntry>{};
    for (final v in vocab) {
      if (v.w.isEmpty) continue;
      final head = v.w[0];
      (map[head] ??= <VocabEntry>[]).add(v);
      byWord.putIfAbsent(v.w, () => v);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.w.length.compareTo(a.w.length));
    }
    return VocabIndex(map, byWord);
  }

  VocabEntry? lookup(String w) => byWord[w];
}

bool _isKanji(String c) => c.codeUnitAt(0) >= 0x4E00 && c.codeUnitAt(0) <= 0x9FFF;
bool _isKana(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x3040 && u <= 0x30FF;
}

// 고단동사 활용 행 → 사전형(う단) 매핑.
const Map<String, String> _i2u = {
  'い': 'う', 'き': 'く', 'ぎ': 'ぐ', 'し': 'す', 'ち': 'つ',
  'に': 'ぬ', 'び': 'ぶ', 'み': 'む', 'り': 'る',
};
const Map<String, String> _a2u = {
  'わ': 'う', 'か': 'く', 'が': 'ぐ', 'さ': 'す', 'た': 'つ',
  'な': 'ぬ', 'ば': 'ぶ', 'ま': 'む', 'ら': 'る',
};
const Map<String, String> _e2u = {
  'え': 'う', 'け': 'く', 'げ': 'ぐ', 'せ': 'す', 'て': 'つ',
  'ね': 'ぬ', 'べ': 'ぶ', 'め': 'む', 'れ': 'る',
};

/// 표면형 s 를 환원해 사전에 존재하는 기본형 entry 를 반환 (없으면 null).
/// 가장 그럴듯한 후보부터 검사.
VocabEntry? deinflectLookup(String s, VocabIndex idx) {
  final cands = <String>[];
  void add(String? x) {
    if (x != null && x.length >= 2) cands.add(x);
  }

  bool ends(String suf) => s.endsWith(suf);
  String cut(String suf) => s.substring(0, s.length - suf.length);
  String? lastKana(String stem) => stem.isEmpty ? null : stem[stem.length - 1];

  // い형용사
  for (final e in const [
    ['くなかった', 'い'], ['かった', 'い'], ['くなくて', 'い'], ['くない', 'い'],
    ['くて', 'い'], ['ければ', 'い'], ['すぎる', 'い'], ['く', 'い'],
  ]) {
    if (ends(e[0])) add(cut(e[0]) + e[1]);
  }

  // ます 정중체
  for (final suf in const [
    'ませんでした', 'ましょう', 'まして', 'ました', 'ません', 'ます', 'ませ'
  ]) {
    if (ends(suf)) {
      final st = cut(suf);
      add('${st}る'); // 1단
      final lk = lastKana(st);
      if (lk != null && _i2u.containsKey(lk)) {
        add(st.substring(0, st.length - 1) + _i2u[lk]!);
      }
    }
  }

  // する 동사: 〜して/している/した/します/しない → 〜する (勉強して→勉強する)
  for (final suf in const [
    'しています', 'している', 'しました', 'しません', 'します',
    'しなかった', 'しない', 'して', 'した', 'すれば', 'しよう'
  ]) {
    if (ends(suf)) add('${cut(suf)}する');
  }

  // て/で · た/だ (음편 포함) + ている
  const teRules = [
    ['いてい', ['く']], ['いでい', ['ぐ']], ['ってい', ['う', 'つ', 'る']],
    ['んでい', ['む', 'ぶ', 'ぬ']],
    ['いて', ['く']], ['いで', ['ぐ']], ['して', ['す']],
    ['って', ['う', 'つ', 'る']], ['んで', ['む', 'ぶ', 'ぬ']],
    ['いた', ['く']], ['いだ', ['ぐ']], ['した', ['す']],
    ['った', ['う', 'つ', 'る']], ['んだ', ['む', 'ぶ', 'ぬ']],
  ];
  for (final r in teRules) {
    final suf = r[0] as String;
    if (ends(suf)) {
      for (final tail in r[1] as List) {
        add(cut(suf) + (tail as String));
      }
    }
  }
  // 1단 て/た/ている
  for (final suf in const ['ている', 'てる', 'てい', 'てから', 'て', 'た']) {
    if (ends(suf)) add('${cut(suf)}る');
  }

  // ない 부정
  for (final suf in const ['なかった', 'なくて', 'なければ', 'ない', 'ず']) {
    if (ends(suf)) {
      final st = cut(suf);
      add('${st}る'); // 1단
      final lk = lastKana(st);
      if (lk != null && _a2u.containsKey(lk)) {
        add(st.substring(0, st.length - 1) + _a2u[lk]!);
      }
    }
  }

  // 수동/사역/가능 れる·られる·せる·させる
  for (final suf in const ['させられる', 'られる', 'させる', 'れる', 'せる']) {
    if (ends(suf)) add('${cut(suf)}る');
  }

  // ば 가정형
  if (ends('ば')) {
    final st = cut('ば');
    final lk = lastKana(st);
    if (lk != null && _e2u.containsKey(lk)) {
      add(st.substring(0, st.length - 1) + _e2u[lk]!);
    }
  }

  // 고단 가능형: e단 + る (書ける→書く)
  if (ends('る') && s.length >= 3) {
    final pen = s[s.length - 2];
    if (_e2u.containsKey(pen)) add(s.substring(0, s.length - 2) + _e2u[pen]!);
  }

  // たい 희망
  if (ends('たかった') || ends('たい')) {
    final st = ends('たい') ? cut('たい') : cut('たかった');
    add('${st}る');
    final lk = lastKana(st);
    if (lk != null && _i2u.containsKey(lk)) {
      add(st.substring(0, st.length - 1) + _i2u[lk]!);
    }
  }

  // 의지형 よう/おう
  if (ends('よう')) add('${cut('よう')}る');

  for (final c in cands) {
    final e = idx.lookup(c);
    if (e != null) return e;
  }
  return null;
}

List<VocabSegment> matchVocab(String text, VocabIndex idx) {
  final out = <VocabSegment>[];
  var buf = StringBuffer();
  final n = text.length;
  int i = 0;
  while (i < n) {
    final head = text[i];
    // 1) 표면형 최장 일치
    VocabEntry? matched;
    final candidates = idx.byHead[head];
    if (candidates != null) {
      for (final c in candidates) {
        if (i + c.w.length <= n && text.substring(i, i + c.w.length) == c.w) {
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
      continue;
    }

    // 2) 한자로 시작하면 활용형 환원 시도
    if (_isKanji(head)) {
      int j = i;
      while (j < n && _isKanji(text[j])) {
        j++;
      }
      int k = j;
      while (k < n && _isKana(text[k]) && (k - i) < 10) {
        k++;
      }
      VocabEntry? base;
      int consumed = 0;
      for (int end = k; end > j; end--) {
        final surface = text.substring(i, end);
        final e = deinflectLookup(surface, idx);
        if (e != null) {
          base = e;
          consumed = end - i;
          break;
        }
      }
      if (base != null) {
        if (buf.isNotEmpty) {
          out.add(VocabSegment(buf.toString(), null));
          buf = StringBuffer();
        }
        out.add(VocabSegment(text.substring(i, i + consumed), base));
        i += consumed;
        continue;
      }
    }

    buf.write(head);
    i++;
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
