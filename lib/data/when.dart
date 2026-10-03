/// 날짜와 시각을 사람이 읽는 말로 적는다.
///
/// 저장은 언제나 UTC 로 해 두고, 사람이 읽는 자리에서만 그 기기의 시간대로
/// 옮긴다. 그래야 다른 시간대에서 백업을 복원해도 적어 둔 때가 밀리지 않는다.
/// 글자 모양은 기기 언어(`AppLocale`)를 따른다 — BuildContext 없이 부르는
/// 자리가 많아 [tr] 대신 이 값을 직접 받는다.
library;

import '../l10n.dart';

String ymd(DateTime at, [AppLocale locale = AppLocale.ko]) {
  final t = at.toLocal();
  return switch (locale) {
    AppLocale.ko => '${t.year}년 ${t.month}월 ${t.day}일',
    AppLocale.en => '${_monthEn[t.month - 1]} ${t.day}, ${t.year}',
    AppLocale.zh => '${t.year}年${t.month}月${t.day}日',
    AppLocale.fr => '${t.day} ${_monthFr[t.month - 1]} ${t.year}',
    AppLocale.ja => '${t.year}年${t.month}月${t.day}日',
  };
}

const _monthEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthFr = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String ymdhm(DateTime at, [AppLocale locale = AppLocale.ko]) {
  final t = at.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return switch (locale) {
    AppLocale.ko =>
      '${ymd(t, locale)} ${t.hour < 12 ? '오전' : '오후'} $hour:$minute',
    AppLocale.en =>
      '${ymd(t, locale)} $hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}',
    AppLocale.zh =>
      '${ymd(t, locale)} ${t.hour < 12 ? '上午' : '下午'} $hour:$minute',
    AppLocale.fr =>
      '${ymd(t, locale)} ${t.hour.toString().padLeft(2, '0')}:$minute',
    AppLocale.ja =>
      '${ymd(t, locale)} ${t.hour < 12 ? '午前' : '午後'} $hour:$minute',
  };
}

/// 목록에서 카드를 묶는 때의 이름.
///
/// 정확한 날짜보다 '오늘 손댔나, 지난주였나'가 먼저 궁금하다. 파일 앱과
/// 사진 앱이 쓰는 묶음과 같은 결로 나눈다.
String whenGroup(
  DateTime at, {
  DateTime? now,
  AppLocale locale = AppLocale.ko,
}) {
  final today = DateUtilsLite.dayOf(now ?? DateTime.now());
  final day = DateUtilsLite.dayOf(at.toLocal());
  final days = today.difference(day).inDays;
  const labels = {
    AppLocale.ko: ('오늘', '어제', '이전 7일', '이전 30일', '이전'),
    AppLocale.en: (
      'Today',
      'Yesterday',
      'Last 7 days',
      'Last 30 days',
      'Earlier',
    ),
    AppLocale.zh: ('今天', '昨天', '最近 7 天', '最近 30 天', '更早'),
    AppLocale.fr: (
      "Aujourd'hui",
      'Hier',
      '7 derniers jours',
      '30 derniers jours',
      'Plus ancien',
    ),
    AppLocale.ja: ('今日', '昨日', '過去7日間', '過去30日間', 'それ以前'),
  };
  final (t, y, w7, w30, rest) = labels[locale]!;
  if (days <= 0) return t;
  if (days == 1) return y;
  if (days <= 7) return w7;
  if (days <= 30) return w30;
  return rest;
}

/// 시각을 떼고 날짜만 남긴다. 자정을 넘겼는지로만 따져야 '어제'가
/// 시간 차이가 아니라 날짜 차이로 읽힌다.
class DateUtilsLite {
  static DateTime dayOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }
}
