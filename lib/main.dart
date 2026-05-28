import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'router.dart';
import 'state/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await Store.instance.init();
  runApp(const JlptApp());
}

class JlptApp extends StatelessWidget {
  const JlptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '엔쓰리노트',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: buildRouter(),
    );
  }
}
