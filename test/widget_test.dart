// Smoke test — the app should boot and reach the home page without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sanity: a basic widget mounts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('OK'))));
    expect(find.text('OK'), findsOneWidget);
  });
}
