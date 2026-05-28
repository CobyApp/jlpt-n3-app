/// 번들된 asset JSON을 로드/캐싱. 카테고리 슬러그 합성 회차도 처리.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';
import 'categories.dart';

class DataLoader {
  DataLoader._();
  static final DataLoader instance = DataLoader._();

  Future<IndexFile>? _indexP;
  final Map<String, Future<Exam>> _examP = {};
  Future<List<VocabEntry>>? _vocabP;
  Future<Map<String, List<String>>>? _kanjiKoP;

  Future<IndexFile> loadIndex() {
    return _indexP ??= _fetchJson('assets/data/index.json')
        .then((j) => IndexFile.fromJson(j as Map<String, dynamic>));
  }

  Future<Exam> loadExam(String id) {
    if (_examP.containsKey(id)) return _examP[id]!;
    if (id.startsWith('cat:')) {
      final p = _loadCategoryAsExam(id.substring(4));
      _examP[id] = p;
      return p;
    }
    final p = loadIndex().then((idx) {
      final entry = idx.exams.firstWhere(
        (e) => e.id == id,
        orElse: () => throw Exception('unknown exam: $id'),
      );
      return _fetchJson('assets/data/${entry.file}')
          .then((j) => Exam.fromJson(j as Map<String, dynamic>));
    });
    _examP[id] = p;
    return p;
  }

  Future<List<VocabEntry>> loadVocab() {
    return _vocabP ??= _fetchJson('assets/data/vocab.json').then((j) {
      final list = (j as List).cast<Map<String, dynamic>>();
      return list.map(VocabEntry.fromJson).toList();
    });
  }

  /// kanji_ko.json: { "漢": ["음", "뜻"], ... }
  Future<Map<String, List<String>>> loadKanjiKo() {
    return _kanjiKoP ??=
        _fetchJson('assets/data/kanji_ko.json').then((j) {
      final map = j as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as List).cast<String>()));
    }).catchError((_) => <String, List<String>>{});
  }

  Future<Exam> _loadCategoryAsExam(String slug) async {
    final cat = categoryFromSlug(slug);
    if (cat == null) throw Exception('unknown category slug: $slug');
    final idx = await loadIndex();
    final exams = await Future.wait(idx.exams.map((e) => loadExam(e.id)));

    final passages = <String, Passage>{};
    final collected = <Question>[];
    for (final e in exams) {
      final label = shortTitle(e.title);
      for (final q in e.questions) {
        if (q.category != cat) continue;
        if (q.passage != null && e.passages[q.passage] != null) {
          passages[q.passage!] = e.passages[q.passage]!;
        }
        collected.add(q.copyWith(srcLabel: label, srcN: q.n));
      }
    }
    final renumbered = <Question>[];
    for (var i = 0; i < collected.length; i++) {
      renumbered.add(collected[i].copyWith(n: i + 1));
    }
    return Exam(
      testId: 'cat:$slug',
      title: '영역별 모음 — ${categoryKo(cat)}',
      sourceUrl: '',
      scrapedAt: '',
      passages: passages,
      questions: renumbered,
      listening: null,
    );
  }

  Future<dynamic> _fetchJson(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw);
  }
}
