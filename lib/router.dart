/// go_router 설정. 웹앱의 hash 라우트와 같은 경로 구조.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'views/home_page.dart';
import 'views/exam_page.dart';
import 'views/question_page.dart';
import 'views/listening_page.dart';
import 'views/wordbook_page.dart';
import 'views/wordlist_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const HomePage()),
      GoRoute(path: '/wordbook', builder: (c, s) => const WordbookPage()),
      GoRoute(
        path: '/exam/:id',
        builder: (c, s) => ExamPage(examId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exam/:id/q/:n',
        builder: (c, s) {
          final from = int.tryParse(s.uri.queryParameters['from'] ?? '');
          final to = int.tryParse(s.uri.queryParameters['to'] ?? '');
          return QuestionPage(
            examId: s.pathParameters['id']!,
            n: int.parse(s.pathParameters['n']!),
            from: from,
            to: to,
          );
        },
      ),
      GoRoute(
        path: '/exam/:id/listen/:m',
        builder: (c, s) => ListeningPage(
          examId: s.pathParameters['id']!,
          m: int.parse(s.pathParameters['m']!),
        ),
      ),
      GoRoute(
        path: '/exam/:id/words',
        builder: (c, s) {
          final raw = s.uri.queryParameters['sections'];
          final sections = (raw == null || raw.isEmpty)
              ? null
              : raw.split(',').where((e) => e.isNotEmpty).toList();
          return WordlistPage(
            examId: s.pathParameters['id']!,
            sections: sections,
          );
        },
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('페이지를 찾을 수 없어요: ${s.uri}')),
    ),
  );
}
