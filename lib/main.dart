import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/memo_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 로컬 파일이 원본이므로, 첫 화면을 그리기 전에 한 번만 읽어 둔다.
  await MemoStore.instance.load();
  runApp(const MallangMemoApp());
}

class MallangMemoApp extends StatelessWidget {
  const MallangMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE9A0B4);
    return MaterialApp(
      title: '말랑 고양이 메모',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          surface: const Color(0xFFFFFBF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFDF6E9),
        splashFactory: NoSplash.splashFactory,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
