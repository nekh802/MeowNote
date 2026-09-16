import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mallang_memo/data/memo_store.dart';
import 'package:mallang_memo/screens/home_screen.dart';
import 'package:mallang_memo/widgets/original_artwork.dart';

/// 화면 전체를 이미지로 떠서 눈으로 확인하기 위한 테스트.
/// `flutter test --update-goldens` 로 PNG 를 새로 뽑는다.
///
/// 위젯 테스트는 pubspec 에 적어둔 서체를 자동으로 싣지 않아 글자가 전부
/// 네모로 나온다. 실제 화면과 같은 그림을 보려면 여기서 직접 실어야 한다.
/// 손글씨는 원본 PNG 에서, 고양이는 오려 둔 PNG 에서 온다. 위젯 테스트는
/// 이미지를 비동기로 읽어 오므로 미리 읽어 두지 않으면 빈 자리로 찍힌다.
Future<void> precacheArtwork(WidgetTester tester) async {
  final context = tester.element(find.byType(HomeScreen));
  for (final asset in [
    OriginalArtwork.asset,
    for (final art in OriginalArtwork.cutouts) OriginalArtwork.cutout(art),
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
}

void main() {
  setUpAll(() async {
    Future<void> load(String family, Future<ByteData> bytes) =>
        (FontLoader(family)..addFont(bytes)).load();

    await load('Jua', rootBundle.load('assets/fonts/Jua-Regular.ttf'));
    await load(
      'GamjaFlower',
      rootBundle.load('assets/fonts/GamjaFlower-Subset.ttf'),
    );

    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File(
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await load(
        'MaterialIcons',
        Future.value(icons.readAsBytesSync().buffer.asByteData()),
      );
    }

    // 본문은 기기 기본 한글 서체를 쓰므로, 미리보기에서도 비슷한 걸 끼운다.
    const kr = '/System/Library/Fonts/Supplemental/AppleGothic.ttf';
    if (File(kr).existsSync()) {
      final data = File(kr).readAsBytesSync().buffer.asByteData();
      await load('Roboto', Future.value(data));
    }
  });

  testWidgets('아이폰에서 메모 하나만 표시하고 전환 후 입력을 유지한다', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MemoStore.instance.debugSeed();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await precacheArtwork(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('줄 추가'), findsOneWidget);
    await tester.tap(find.byTooltip('줄 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '오늘의 작은 행복');
    await tester.tap(find.widgetWithText(ChoiceChip, '하나씩 해볼까'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byTooltip('줄 추가'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '오늘의 메모'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 작은 행복'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/iphone.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('홈 화면 전체', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    MemoStore.instance.debugSeed();

    await tester.pumpWidget(
      const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()),
    );
    await tester.pumpAndSettle();

    await precacheArtwork(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  });
}
