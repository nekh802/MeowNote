import 'package:flutter/widgets.dart';

/// 이 앱이 지원하는 말. 기기 언어가 이 밖이면 한국어로 보인다.
enum AppLocale { ko, en, zh, fr, ja }

/// 지금 기기가 이 다섯 중 무엇으로 뜨는지. `main.dart` 의 `supportedLocales` 에
/// 있는 언어끼리는 Flutter 가 기기 언어와 가장 가깝게 알아서 골라 준다 —
/// 여기서는 그 결과(`Localizations.localeOf`)를 다섯 중 하나로 좁히기만 한다.
AppLocale localeOf(BuildContext context) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => AppLocale.en,
      'zh' => AppLocale.zh,
      'fr' => AppLocale.fr,
      'ja' => AppLocale.ja,
      _ => AppLocale.ko,
    };

/// 화면 글씨를 이 자리에서 바로 옮긴다.
///
/// 번역이 저 멀리 딴 파일에 있으면 원문과 번역이 따로 놀아 어느 한쪽만
/// 고치기 쉽다. `tr(context, '완료', en: 'Done', zh: '完成')` 처럼 쓰는 곳에서
/// 바로 다섯 말을 나란히 두면, 한글을 고칠 때 번역도 눈에 걸려 함께 고치게
/// 된다. `en`·`zh`·`fr`·`ja` 를 아직 못 채웠으면 한국어가 그대로 나간다.
String tr(
  BuildContext context,
  String ko, {
  String? en,
  String? zh,
  String? fr,
  String? ja,
}) => switch (localeOf(context)) {
  AppLocale.en => en ?? ko,
  AppLocale.zh => zh ?? ko,
  AppLocale.fr => fr ?? ko,
  AppLocale.ja => ja ?? ko,
  AppLocale.ko => ko,
};

/// 위젯 트리 밖 — 저장소나 내보내기 글처럼 BuildContext 가 없는 자리에서
/// 쓴다. 기기 언어를 직접 읽는다.
String trLocale(
  AppLocale locale,
  String ko, {
  String? en,
  String? zh,
  String? fr,
  String? ja,
}) => switch (locale) {
  AppLocale.en => en ?? ko,
  AppLocale.zh => zh ?? ko,
  AppLocale.fr => fr ?? ko,
  AppLocale.ja => ja ?? ko,
  AppLocale.ko => ko,
};

/// BuildContext 가 없는 자리(저장소, 위젯 갱신)에서 쓸 기기 언어. 앱이 실제로
/// 그리는 언어와 같은 기준(지원하는 다섯 말 중 하나)으로 좁힌다.
AppLocale get platformLocale =>
    switch (WidgetsBinding.instance.platformDispatcher.locale.languageCode) {
      'en' => AppLocale.en,
      'zh' => AppLocale.zh,
      'fr' => AppLocale.fr,
      'ja' => AppLocale.ja,
      _ => AppLocale.ko,
    };
