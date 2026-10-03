import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/app_update.dart';

void main() {
  test('10 이 9 보다 새 판이다 — 글자 순서로 견주지 않는다', () {
    expect(isNewerVersion('1.10.0', '1.9.1'), isTrue);
    expect(isNewerVersion('1.9.1', '1.10.0'), isFalse);
    expect(isNewerVersion('1.9.2', '1.9.1'), isTrue);
    expect(isNewerVersion('2.0', '1.9.9'), isTrue);
  });

  test('같은 판이나 옛 판이면 알리지 않는다', () {
    expect(isNewerVersion('1.9.1', '1.9.1'), isFalse);
    expect(isNewerVersion('1.9', '1.9.0'), isFalse);
    expect(isNewerVersion('1.8.9', '1.9.1'), isFalse);
  });

  test('앱스토어 답에서 판·앱스토어 주소·바뀐 점을 뽑는다', () {
    const body = '''
{"resultCount":1,"results":[{
  "version":"1.10.0",
  "trackId":6812345678,
  "trackViewUrl":"https://apps.apple.com/kr/app/meow-note/id6812345678?uo=4",
  "releaseNotes":"  사진을 메모 안에 넣을 수 있어요.  "
}]}''';
    final r = AppUpdate.parseRelease(body)!;
    expect(r.version, '1.10.0');
    // 브라우저를 거치지 않고 앱스토어 앱으로 바로 간다.
    expect(r.page.toString(), 'itms-apps://apps.apple.com/app/id6812345678');
    expect(r.fallbackPage.host, 'apps.apple.com');
    expect(r.notes, '사진을 메모 안에 넣을 수 있어요.');
  });

  test('아직 스토어에 없는 앱이나 이상한 답은 조용히 넘어간다', () {
    expect(AppUpdate.parseRelease('{"resultCount":0,"results":[]}'), isNull);
    expect(AppUpdate.parseRelease('not json'), isNull);
    expect(AppUpdate.parseRelease('{"results":[{"trackId":1}]}'), isNull);
  });

  test('trackId 가 없으면 브라우저 주소로 간다', () {
    const body =
        '{"results":[{"version":"2.0","trackViewUrl":"https://apps.apple.com/kr/app/x/id1"}]}';
    final r = AppUpdate.parseRelease(body)!;
    expect(r.page, r.fallbackPage);
  });
}
