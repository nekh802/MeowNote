import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';
import 'package:malang_cat/screens/reference_home.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Jua',
    )..addFont(rootBundle.load('assets/fonts/Jua-Regular.ttf'))).load();
  });
  for (final size in [const Size(390, 844), const Size(1536, 1024)]) {
    testWidgets('한 장씩 전환과 작성 ${size.width}', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      MemoStore.instance.debugSeed();
      await tester.pumpWidget(const MaterialApp(home: ReferenceHome()));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/malang_reference_rgb.png'),
          tester.element(find.byType(ReferenceHome)),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/malang_reference_rgb.png'),
          tester.element(find.byType(ReferenceHome)),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ReferenceHome),
        matchesGoldenFile(
          size.width < 720
              ? 'goldens/reference_iphone.png'
              : 'goldens/reference.png',
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '하나씩 해볼까'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
