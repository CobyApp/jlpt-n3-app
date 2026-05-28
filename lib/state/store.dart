/// localStorage 대용 — SharedPreferences 기반의 영구 상태.
/// 웹 앱과 동일한 키를 그대로 쓰지는 않지만 의미가 같음.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class Settings {
  final bool furigana;
  final bool dark;
  const Settings({this.furigana = false, this.dark = false});

  Settings copyWith({bool? furigana, bool? dark}) =>
      Settings(furigana: furigana ?? this.furigana, dark: dark ?? this.dark);

  Map<String, dynamic> toJson() => {'furigana': furigana, 'dark': dark};

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        furigana: j['furigana'] as bool? ?? false,
        dark: j['dark'] as bool? ?? false,
      );
}

/// 싱글톤 스토어. 모든 화면이 이 인스턴스의 ChangeNotifier들을 듣는다.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _prefs;
  bool _ready = false;

  // Keys
  static const _kProgress = 'jlpt:progress';
  static const _kLast = 'jlpt:last';
  static const _kSettings = 'jlpt:settings';
  static const _kWordbook = 'jlpt:wordbook';
  static const _kListenProgress = 'jlpt:listen-progress';
  static const _kHomeTab = 'jlpt:home-tab';
  static const _kSrs = 'jlpt:srs';

  bool get ready => _ready;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  // ── Internal helpers ──
  Map<String, dynamic> _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {};
  }

  Future<void> _writeMap(String key, Map<String, dynamic> v) async {
    await _prefs.setString(key, jsonEncode(v));
  }

  // ── Progress (reading) ──
  Map<int, AnswerRec> getProgress(String examId) {
    final all = _readMap(_kProgress);
    final exam = all[examId];
    if (exam is! Map) return {};
    return exam.map((k, v) =>
        MapEntry(int.parse(k.toString()), AnswerRec.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> recordAnswer(
      String examId, int n, int picked, bool correct) async {
    final all = _readMap(_kProgress);
    final exam = (all[examId] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(all[examId] as Map)
        : <String, dynamic>{};
    exam[n.toString()] =
        AnswerRec(picked: picked, correct: correct, ts: _ts()).toJson();
    all[examId] = exam;
    await _writeMap(_kProgress, all);
    notifyListeners();
  }

  // ── Last position ──
  LastPos? getLast() {
    final raw = _prefs.getString(_kLast);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return LastPos.fromJson(v);
    } catch (_) {}
    return null;
  }

  Future<void> setLast(String examId, int n) async {
    await _prefs.setString(
      _kLast,
      jsonEncode(LastPos(examId: examId, questionN: n, ts: _ts()).toJson()),
    );
    notifyListeners();
  }

  // ── Settings ──
  Settings getSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const Settings();
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return Settings.fromJson(v);
    } catch (_) {}
    return const Settings();
  }

  Future<void> setSettings(Settings s) async {
    await _prefs.setString(_kSettings, jsonEncode(s.toJson()));
    notifyListeners();
  }

  // ── Wordbook ──
  List<WordbookEntry> getWordbook() {
    final raw = _prefs.getString(_kWordbook);
    if (raw == null) return [];
    try {
      final v = jsonDecode(raw);
      if (v is List) {
        return v
            .map((e) {
              if (e is String) return WordbookEntry(w: e, ts: 0);
              if (e is Map<String, dynamic>) return WordbookEntry.fromJson(e);
              return null;
            })
            .whereType<WordbookEntry>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  bool isInWordbook(String w) => getWordbook().any((e) => e.w == w);

  Future<void> addToWordbook(String w) async {
    if (w.isEmpty) return;
    final list = getWordbook();
    if (list.any((e) => e.w == w)) return;
    list.add(WordbookEntry(w: w, ts: _ts()));
    await _prefs.setString(
        _kWordbook, jsonEncode(list.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> removeFromWordbook(String w) async {
    final list = getWordbook().where((e) => e.w != w).toList();
    await _prefs.setString(
        _kWordbook, jsonEncode(list.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<bool> toggleWordbook(String w) async {
    if (isInWordbook(w)) {
      await removeFromWordbook(w);
      return false;
    }
    await addToWordbook(w);
    return true;
  }

  Future<void> clearWordbook() async {
    await _prefs.setString(_kWordbook, jsonEncode([]));
    notifyListeners();
  }

  // ── Listening progress ──
  /// 청해 진도는 questionId(string) 기준으로 저장된다.
  Map<String, AnswerRec> getListenProgress(String examId) {
    final all = _readMap(_kListenProgress);
    final exam = all[examId];
    if (exam is! Map) return {};
    return exam.map((k, v) => MapEntry(
          k.toString(),
          AnswerRec.fromJson(v as Map<String, dynamic>),
        ));
  }

  Future<void> recordListenAnswer(
      String examId, String questionId, int picked, bool correct) async {
    final all = _readMap(_kListenProgress);
    final exam = (all[examId] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(all[examId] as Map)
        : <String, dynamic>{};
    exam[questionId] =
        AnswerRec(picked: picked, correct: correct, ts: _ts()).toJson();
    all[examId] = exam;
    await _writeMap(_kListenProgress, all);
    notifyListeners();
  }

  // ── Reset helpers ──
  Future<void> clearExamProgress(String examId) async {
    final r = _readMap(_kProgress)..remove(examId);
    await _writeMap(_kProgress, r);
    final l = _readMap(_kListenProgress)..remove(examId);
    await _writeMap(_kListenProgress, l);
    notifyListeners();
  }

  Future<void> clearAllProgress() async {
    await _writeMap(_kProgress, {});
    await _writeMap(_kListenProgress, {});
    await _prefs.remove(_kLast);
    notifyListeners();
  }

  // ── SRS ──
  Map<String, SrsRec> getAllSrs() {
    final all = _readMap(_kSrs);
    final out = <String, SrsRec>{};
    all.forEach((k, v) {
      if (v is Map<String, dynamic>) out[k] = SrsRec.fromJson(v);
    });
    return out;
  }

  SrsRec getSrs(String w) => getAllSrs()[w] ?? const SrsRec();

  Future<void> recordSrs(String w, SrsAction action) async {
    final all = _readMap(_kSrs);
    final raw = all[w];
    var cur = raw is Map<String, dynamic>
        ? SrsRec.fromJson(raw)
        : const SrsRec();
    final ts = _ts();
    final seen = cur.seen + 1;
    int level = cur.level;
    int correct = cur.correct;
    int wrong = cur.wrong;
    switch (action) {
      case SrsAction.again:
        wrong += 1;
        level = level >= 0 ? (level - 1).clamp(0, 5) : 0;
      case SrsAction.easy:
        correct += 1;
        level = level < 0 ? 1 : (level + 1).clamp(0, 5);
      case SrsAction.skip:
        if (level < 0) level = 0;
    }
    cur = cur.copyWith(
      level: level,
      seen: seen,
      correct: correct,
      wrong: wrong,
      lastTs: ts,
    );
    all[w] = cur.toJson();
    await _writeMap(_kSrs, all);
    notifyListeners();
  }

  Future<void> clearSrs() async {
    await _writeMap(_kSrs, {});
    notifyListeners();
  }

  // ── Home tab persistence ──
  String getHomeTab() => _prefs.getString(_kHomeTab) ?? 'exams';
  Future<void> setHomeTab(String t) async {
    await _prefs.setString(_kHomeTab, t);
    notifyListeners();
  }

  int _ts() => DateTime.now().millisecondsSinceEpoch;
}
