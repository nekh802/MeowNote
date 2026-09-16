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
