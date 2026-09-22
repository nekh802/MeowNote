import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/memo_store.dart';
import 'screens/home_screen.dart';
import 'theme/palette.dart';

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
      title: 'Malang Cat',
      debugShowCheckedModeBanner: false,
      // 기기 언어를 그대로 따른다. 한국어·영어·중국어 밖의 언어는 Flutter 가
      // 첫 번째로 적어 둔 한국어로 내려온다.
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
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
        // 음영은 꾸미기 창 안에서만 쓴다. 메모를 적는 칸은 종이 그대로여야
        // 하므로, 앱 기본 글칸에는 바탕을 깔지 않는다.
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppTone.buttonFill,
            foregroundColor: AppTone.buttonEdge,
            disabledBackgroundColor: AppTone.picked,
            disabledForegroundColor: AppTone.ink.withValues(alpha: .45),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            textStyle: const TextStyle(fontSize: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTone.radius),
              side: const BorderSide(color: AppTone.buttonEdge, width: 1.2),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
