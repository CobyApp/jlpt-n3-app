/// 회차/카테고리 카드용 진도바.
library;

import 'package:flutter/material.dart';

class ProgressTrack extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final double height;
  const ProgressTrack({
    super.key,
    required this.progress,
    this.color = const Color(0xFFD6336C),
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: const Color(0xFFE5E7EB),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: p,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}
