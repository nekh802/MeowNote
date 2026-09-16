import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/app_update.dart';
import 'package:malang_cat/data/memo_store.dart';
import 'package:malang_cat/models/memo.dart';

void main() {
  final store = MemoStore.instance;

  setUp(() {
    store.debugSeed();
    store.setSort(BoardSort.edited);
  });

  test('갓 깐 기기에서는 카드가 놓인 차례 그대로 선다', () {
    // 기본 카드는 모두 같은 때에 놓인다. 마이크로초 차이로 줄이
    // 뒤집히면 처음 켠 사람이 '내일 또 만나'부터 보게 된다.
    expect(store.boards.first.title, '오늘의 메모');
    expect(store.boards.last.title, '내일 또 만나');
  });

  test('편집일 순은 마지막으로 손댄 카드를 앞에 세운다', () {
    final last = store.boards.last;
    store.updateBoard(last.id, subtitle: '방금 고친 카드');
    expect(store.boards.first.id, last.id);
  });

  test('생성일 순은 처음 만든 차례를 따른다', () {
    final last = store.boards.last;
    store.updateBoard(last.id, subtitle: '방금 고친 카드');
    store.setSort(BoardSort.created);
    expect(store.boards.first.title, '오늘의 메모');
  });

  test('가나다·ABC 순은 제목으로 줄 세운다', () {
    store.setSort(BoardSort.name);
    final titles = store.boards.map((b) => b.title).toList();
    final sorted = [...titles]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    expect(titles, sorted);
  });

  test('붙박은 카드는 어떤 차례에서도 앞선다', () {
    final last = store.boards.last;
    store.togglePin(last.id);

    expect(store.boards.first.id, last.id);
    expect(store.pinnedBoards.map((b) => b.id), [last.id]);
    expect(store.looseBoards.any((b) => b.id == last.id), isFalse);

    // 붙박는 것은 내용을 고치는 일이 아니다 — 편집일이 밀리면 안 된다.
    store.togglePin(last.id);
    expect(store.boards.last.id, last.id);
  });

  test('판 견주기는 글자가 아니라 숫자로 한다', () {
    expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
    expect(isNewerVersion('1.2.1', '1.2.0'), isTrue);
    expect(isNewerVersion('2.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('1.1.9', '1.2.0'), isFalse);
  });

  test('노을과 마음 비우기는 기본 카드에서 빠졌다', () {
    final titles = store.boards.map((b) => b.title);
    expect(titles, isNot(contains('마음 비우기')));
    expect(store.boards.every((b) => b.catId != 'noeul'), isTrue);
  });

  test('이름 순은 기기 기본 언어를 앞세운다', () {
    store.setSort(BoardSort.name);
    final ko = store.addBoard(colorKey: 'sky', catId: 'mochi');
    store.updateBoard(ko.id, title: '가나다');
    final en = store.addBoard(colorKey: 'sky', catId: 'mochi');
    store.updateBoard(en.id, title: 'Apple');

    store.uiLanguage = 'ko';
    expect(store.boards.first.title, '가나다');
    expect(store.boards.last.title, 'Apple');

    store.uiLanguage = 'en';
    expect(store.boards.first.title, 'Apple');
    expect(store.boards.last.title, isNot('Apple'));
  });
}
