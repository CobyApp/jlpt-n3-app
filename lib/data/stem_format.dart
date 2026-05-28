/// 긁어올 때 표/도표 구조가 평문으로 짓이겨진 문제(정보 검색 등)의
/// stem 텍스트를 후처리해서 가독성 있게 줄바꿈을 복원한다.
///
/// 접근: 옵션 텍스트가 stem 안에 출현하는 위치를 행 구분자로 삼아
/// 옵션 등장 직전마다 줄바꿈을 삽입.
library;

/// 정보 검색 등 표 형식 문제의 stem 을 다듬어 line break 를 복원.
/// 옵션이 stem 안에 2개 이상 출현해야 표로 인정하고 분리.
String formatTableStem(String stem, List<String> opts) {
  if (stem.trim().isEmpty || opts.length < 2) return stem;

  // 옵션의 stem 내 위치 수집 (출현 순서대로).
  final positions = <int>[];
  for (final opt in opts) {
    final t = opt.trim();
    if (t.isEmpty) continue;
    final pos = stem.indexOf(t);
    if (pos < 0) {
      // 옵션 하나라도 못 찾으면 표가 아닐 가능성이 높음 — 그대로 반환.
      return _addParagraphBreaks(stem);
    }
    positions.add(pos);
  }
  if (positions.length < 2) return _addParagraphBreaks(stem);

  // 출현 순서대로 정렬.
  positions.sort();

  // 첫 옵션 앞 = 질문 인트로 + 헤더 행 (있을 수 있음)
  final intro = stem.substring(0, positions[0]);
  // 각 옵션 위치 ~ 다음 옵션 위치 = 한 행
  final rows = <String>[];
  for (var i = 0; i < positions.length; i++) {
    final start = positions[i];
    final end = i + 1 < positions.length ? positions[i + 1] : stem.length;
    rows.add(stem.substring(start, end).trim());
  }

  // 인트로 안에서 질문(. /。/？ 로 끝남) 과 헤더 행을 분리 시도.
  final introTrim = intro.trim();
  String question = introTrim;
  String header = '';
  final endIdx = _lastPunctIndex(introTrim, ['。', '？', '?']);
  if (endIdx > 0 && endIdx < introTrim.length - 1) {
    question = introTrim.substring(0, endIdx + 1);
    header = introTrim.substring(endIdx + 1).trim();
  }

  final out = StringBuffer();
  out.writeln(question);
  out.writeln();
  if (header.isNotEmpty) {
    out.writeln(header);
    out.writeln();
  }
  for (final r in rows) {
    out.writeln('· $r');
  }
  return out.toString().trim();
}

/// 표가 아닌 일반 stem 의 가독성도 살짝 개선 — 마침표/물음표 뒤
/// 충분히 긴 텍스트면 한 줄 줄바꿈.
String _addParagraphBreaks(String s) {
  return s.replaceAllMapped(
    RegExp(r'([。？?])\s*([^\s])'),
    (m) {
      // 너무 짧은 인트로는 줄바꿈 안 함
      return '${m[1]}\n${m[2]}';
    },
  );
}

int _lastPunctIndex(String s, List<String> puncts) {
  int last = -1;
  for (final p in puncts) {
    final i = s.lastIndexOf(p);
    if (i > last) last = i;
  }
  return last;
}
