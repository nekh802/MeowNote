import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';
import 'package:malang_cat/screens/home_screen.dart';

/// 줄을 쓰고 지우는 손놀림. 칸에 보이지 않는 글자를 세워 두는 방식이라
/// 눈으로는 확인하기 어려워 여기서 지켜본다.
void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    MemoStore.instance.debugSeed();
    await tester.pumpWidget(
      const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()),
    );
    await tester.pumpAndSettle();
  }

  /// 저장은 400ms 뒤에 한 번에 한다. 그 타이머를 남기지 않고 끝낸다.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('엔터는 줄바꿈 대신 아랫 줄로 간다', (tester) async {
    await open(tester, const Size(390, 844));
    final board = MemoStore.instance.boards.first;

    await tester.tap(find.byTooltip('줄 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '첫 줄\n');
    await tester.pumpAndSettle();

    final entries = MemoStore.instance.entriesOf(board.id);
    expect(entries.first.text, '첫 줄');
    expect(entries.length, 2);
    await close(tester);
  });

  testWidgets('아무것도 안 적힌 줄에서 지우면 그 줄이 사라진다', (tester) async {
    await open(tester, const Size(390, 844));
    final board = MemoStore.instance.boards.first;

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('줄 추가'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, '남는 줄');
    await tester.pumpAndSettle();
    expect(MemoStore.instance.entriesOf(board.id).length, 3);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();

    expect(MemoStore.instance.entriesOf(board.id).length, 2);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(MemoStore.instance.entriesOf(board.id).first.text, '남는 줄');
    await close(tester);
  });

  testWidgets('줄이 줄면 카드도 그만큼 짧아진다', (tester) async {
    await open(tester, const Size(390, 1400));

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('줄 추가'));
      await tester.pumpAndSettle();
    }
    final card = find.byType(BackdropFilter).first;
    final tall = tester.getSize(card).height;

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();

    expect(tester.getSize(card).height, lessThan(tall));
    await close(tester);
  });

  testWidgets('엔터는 맨 아래가 아니라 누른 줄 바로 아래에 새 줄을 놓는다', (tester) async {
    await open(tester, const Size(390, 1000));
    final board = MemoStore.instance.boards.first;

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('줄 추가'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, '첫 줄');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '둘째 줄');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '첫 줄\n');
    await tester.pumpAndSettle();

    final texts = MemoStore.instance
        .entriesOf(board.id)
        .map((e) => e.text)
        .toList();
    expect(texts, ['첫 줄', '', '둘째 줄']);
    await close(tester);
  });

  testWidgets('적어 둔 주소는 눌러서 열 수 있게 그린다', (tester) async {
    await open(tester, const Size(390, 900));

    await tester.tap(find.byTooltip('줄 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      '참고 https://flutter.dev 보기',
    );
    await tester.pumpAndSettle();

    // 쓰는 중에는 그대로 칸이다.
    expect(find.byType(TextField), findsOneWidget);

    // 커서가 떠나면 주소만 눌리는 글로 바뀐다.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('flutter.dev', findRichText: true),
      findsWidgets,
    );

    // 주소가 아닌 자리를 누르면 다시 쓰던 칸으로 돌아온다.
    await tester.tap(find.textContaining('참고', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await close(tester);
  });

  testWidgets('엔터를 누르면 커서가 새로 생긴 줄로 내려간다', (tester) async {
    await open(tester, const Size(390, 900));

    await tester.tap(find.byTooltip('줄 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '첫 줄\n');
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields.length, 2);
    expect(fields.first.focusNode.hasFocus, isFalse);
    expect(fields.last.focusNode.hasFocus, isTrue);
    await close(tester);
  });

  testWidgets('하트는 만든 줄마다 찍고 장식 괘선에는 찍지 않는다', (tester) async {
    await open(tester, const Size(390, 1000));

    // 하트 줄 카드로 옮겨 간다.
    await tester.tap(find.byTooltip('목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기분 좋은 시작'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('줄 추가'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, '첫 줄');
    await tester.pumpAndSettle();

    final board = MemoStore.instance.boards.firstWhere(
      (b) => b.title == '기분 좋은 시작',
    );
    final rows = MemoStore.instance.entriesOf(board.id).length;

    // 만든 줄에는 모두 하트가 서고, 카드를 채우는 빈 괘선에는 서지 않는다.
    expect(rows, greaterThan(1));
    expect(find.byIcon(Icons.favorite), findsNWidgets(rows));
    expect(find.text('적어보기'), findsOneWidget);
    await close(tester);
  });

  testWidgets('블록을 꾸욱 누르면 목록 맨 위에 붙박는다', (tester) async {
    await open(tester, const Size(390, 1000));

    await tester.tap(find.byTooltip('목록'));
    await tester.pumpAndSettle();
    expect(find.text('고정된 메모'), findsNothing);

    // 같은 제목이 ∨ 박스에도 설 수 있어 블록만 집어 누른다.
    final chip = find.descendant(
      of: find.byType(Wrap),
      matching: find.text('내일 또 만나'),
    );
    await tester.longPress(chip);
    await tester.pumpAndSettle();

    expect(find.text('고정된 메모'), findsOneWidget);
    expect(find.text('모든 메모'), findsOneWidget);
    expect(MemoStore.instance.boards.first.title, '내일 또 만나');

    // 한 번 더 꾸욱 누르면 떼어진다.
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    expect(find.text('고정된 메모'), findsNothing);
    await close(tester);
  });

  testWidgets('검색칸에 적으면 그 말이 든 메모만 남는다', (tester) async {
    await open(tester, const Size(390, 1100));
    await tester.tap(find.byTooltip('목록'));
    await tester.pumpAndSettle();

    final blocks = find.descendant(
      of: find.byType(Wrap),
      matching: find.byType(Text),
    );
    final before = tester.widgetList<Text>(blocks).length;

    await tester.enterText(find.byKey(const Key('memo-search')), '쉬어');
    await tester.pumpAndSettle();

    expect(find.text('잠깐 쉬어가기'), findsWidgets);
    expect(find.text('하나씩 해볼까'), findsNothing);
    expect(tester.widgetList<Text>(blocks).length, lessThan(before));
    await close(tester);
  });

  testWidgets('[+] 블록으로 새 메모를 놓는다', (tester) async {
    await open(tester, const Size(390, 1100));
    await tester.tap(find.byTooltip('목록'));
    await tester.pumpAndSettle();
    final before = MemoStore.instance.boards.length;

    await tester.tap(find.byTooltip('새 메모'));
    await tester.pumpAndSettle();

    expect(MemoStore.instance.boards.length, before + 1);
    // 놓자마자 그 메모가 펼쳐진다.
    expect(find.byTooltip('목록'), findsOneWidget);
    expect(find.text('새 메모'), findsWidgets);
    await close(tester);
  });
}
