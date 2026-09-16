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
}
