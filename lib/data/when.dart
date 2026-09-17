/// 날짜와 시각을 한국어로 적는다.
///
/// 저장은 언제나 UTC 로 해 두고, 사람이 읽는 자리에서만 그 기기의 시간대로
/// 옮긴다. 그래야 다른 시간대에서 백업을 복원해도 적어 둔 때가 밀리지 않는다.
library;

String ymd(DateTime at) {
  final t = at.toLocal();
  return '${t.year}년 ${t.month}월 ${t.day}일';
}

String ymdhm(DateTime at) {
  final t = at.toLocal();
  final ampm = t.hour < 12 ? '오전' : '오후';
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${ymd(t)} $ampm $hour:${t.minute.toString().padLeft(2, '0')}';
}

/// 목록에서 카드를 묶는 때의 이름.
///
/// 정확한 날짜보다 '오늘 손댔나, 지난주였나'가 먼저 궁금하다. 파일 앱과
/// 사진 앱이 쓰는 묶음과 같은 결로 나눈다.
String whenGroup(DateTime at, {DateTime? now}) {
  final today = DateUtilsLite.dayOf(now ?? DateTime.now());
  final day = DateUtilsLite.dayOf(at.toLocal());
  final days = today.difference(day).inDays;
  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  if (days <= 7) return '이전 7일';
  if (days <= 30) return '이전 30일';
  return '이전';
}

/// 시각을 떼고 날짜만 남긴다. 자정을 넘겼는지로만 따져야 '어제'가
/// 시간 차이가 아니라 날짜 차이로 읽힌다.
class DateUtilsLite {
  static DateTime dayOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }
}
