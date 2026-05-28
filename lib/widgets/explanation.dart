/// 해설 텍스트를 라벨 단위로 파싱해서 가독성 있게 블록 단위로 렌더링.
///
/// 인식하는 라벨: 정답 / 핵심 이유 / 핵심 / 이유 / 해설 / 오답 / 오답 분석 /
/// 포인트 / 학습 포인트 / 어휘 / 문법 / 해석 / 의미.
///
/// "오답 분석" 같이 1./2./3. 패턴이면 list 로 풀어서 표시.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

const List<String> _explLabels = [
  '정답', '핵심 이유', '핵심', '이유', '해설',
  '오답 분석', '오답',
  '포인트', '학습 포인트', '어휘', '문법', '해석', '의미',
];

/// (?:^|\s)(label1|label2|...)\s*[:：]\s*  — 라벨 패턴.
final RegExp _labelRe = RegExp(
  r'(?:^|\s)(' +
      _explLabels.map((l) => l.replaceAll(' ', r'\s')).join('|') +
      r')\s*[:：]\s*',
);

class _Match {
  final String label;
  final int start; // label 시작 offset
  final int bodyStart; // body 시작 offset
  _Match(this.label, this.start, this.bodyStart);
}

class _Block {
  final String? label; // null = lead text
  final String body;
  _Block(this.label, this.body);
}

List<_Block> _parse(String text) {
  final matches = <_Match>[];
  for (final m in _labelRe.allMatches(text)) {
    // m[0] 앞에 공백이 있을 수 있어 trim 시작점 계산.
    final pre = m[0]!.length - m[0]!.trimLeft().length;
    matches.add(_Match(m.group(1)!, m.start + pre, m.end));
  }
  final blocks = <_Block>[];
  if (matches.isEmpty) {
    final t = text.trim();
    if (t.isNotEmpty) blocks.add(_Block(null, t));
    return blocks;
  }
  // lead
  if (matches.first.start > 0) {
    final lead = text.substring(0, matches.first.start).trim();
    if (lead.isNotEmpty) blocks.add(_Block(null, lead));
  }
  for (var i = 0; i < matches.length; i++) {
    final cur = matches[i];
    final end = (i + 1 < matches.length) ? matches[i + 1].start : text.length;
    var body = text.substring(cur.bodyStart, end).trim();
    // 끝에 . 이나 , 만 남아있으면 떼버린다.
    body = body.replaceAll(RegExp(r'[.,]\s*$'), '');
    blocks.add(_Block(cur.label, body));
  }
  return blocks;
}

class Explanation extends StatelessWidget {
  final String text;
  final Color labelColor;
  final TextStyle? bodyStyle;
  final double blockGap;

  const Explanation({
    super.key,
    required this.text,
    this.labelColor = brandPrimary,
    this.bodyStyle,
    this.blockGap = 10,
  });

  @override
  Widget build(BuildContext context) {
    final body = bodyStyle ??
        const TextStyle(
          fontSize: 14,
          height: 1.65,
          color: ink2,
        );
    final blocks = _parse(text);
    if (blocks.isEmpty) {
      return Text('(해설 없음)', style: body.copyWith(color: textMuted));
    }
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) children.add(SizedBox(height: blockGap));
      children.add(_block(b, body));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _block(_Block b, TextStyle bodyStyle) {
    if (b.label == null) {
      return Text(b.body, style: bodyStyle);
    }
    // 오답 분석 형태 — "1. ~, 2. ~, 3. ~" 면 list 로.
    if (b.label!.startsWith('오답')) {
      final items = b.body
          .split(RegExp(r'(?:^|[,，、])\s*(?=\d\s*[.\.．]\s*)'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.length >= 2) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _labelChip(b.label!),
            const SizedBox(height: 6),
            ...items.map((it) {
              final m = RegExp(r'^(\d)\s*[.\.．]\s*(.*)$', dotAll: true)
                  .firstMatch(it);
              final num = m?.group(1);
              final body = m?.group(2)?.trim() ?? it;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 22,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        num != null ? '$num.' : '•',
                        style: bodyStyle.copyWith(
                          fontWeight: FontWeight.w900,
                          color: labelColor,
                        ),
                      ),
                    ),
                    Expanded(child: Text(body, style: bodyStyle)),
                  ],
                ),
              );
            }),
          ],
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelChip(b.label!),
        const SizedBox(height: 4),
        Text(b.body, style: bodyStyle),
      ],
    );
  }

  Widget _labelChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: labelColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: labelColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
