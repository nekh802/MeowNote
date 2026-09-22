import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/widgets/resizable_block.dart';

void main() {
  /// 저장소처럼, 알려 준 값을 받아 다시 그려 주는 화면.
  Widget host({
    required double fraction,
    required ValueChanged<double> onResized,
    ScrollController? scroll,
  }) {
    var saved = fraction;
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            controller: scroll,
            // 글이 밀리는 상자 안에 넣어, 끌기가 글을 함께 미는지 본다.
            child: Column(
              children: [
                const SizedBox(height: 40),
                SizedBox(
                  width: 400,
                  child: ResizableBlock(
                    fraction: saved,
                    onResized: (v) {
                      setState(() => saved = v);
                      onResized(v);
                    },
                    builder: (context, w, max) => Container(
                      key: const Key('media'),
                      width: w,
                      height: 100,
                      color: Colors.pink,
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('저장된 몫만큼의 너비로 그린다', (tester) async {
    await tester.pumpWidget(host(fraction: .5, onResized: (_) {}));
    expect(tester.getSize(find.byKey(const Key('media'))).width, 200);
  });

  testWidgets('손잡이를 오른쪽으로 끌면 커지고, 손을 뗄 때 한 번만 알린다', (tester) async {
    final done = <double>[];
    await tester.pumpWidget(host(fraction: .5, onResized: done.add));
    final handle = find.byKey(const Key('resizeHandle'));
    expect(handle, findsOneWidget);

    final g = await tester.startGesture(tester.getCenter(handle));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    // 끄는 동안에는 알리지 않고 화면만 바뀐다: (200 + 40) / 400 = .6
    expect(done, isEmpty);
    expect(tester.getSize(find.byKey(const Key('media'))).width, 240);
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(done, hasLength(1));
    expect(done.single, closeTo(.7, 1e-6));
  });

  testWidgets('세로로 끌어도 글이 밀려 가지 않는다', (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      host(fraction: .5, onResized: (_) {}, scroll: scroll),
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('resizeHandle'))),
    );
    await g.moveBy(const Offset(0, -120));
    await g.moveBy(const Offset(10, -120));
    await g.up();
    await tester.pump();
    expect(scroll.offset, 0);
  });

  testWidgets('가장 작게도 가장 크게도 한계를 넘지 않는다', (tester) async {
    final done = <double>[];
    await tester.pumpWidget(host(fraction: .5, onResized: done.add));
    var g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('resizeHandle'))),
    );
    await g.moveBy(const Offset(900, 0));
    await g.up();
    await tester.pump();
    expect(done.last, 1.0);
    expect(tester.getSize(find.byKey(const Key('media'))).width, 400);

    g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('resizeHandle'))),
    );
    await g.moveBy(const Offset(-900, 0));
    await g.up();
    await tester.pump();
    expect(done.last, closeTo(.2, 1e-6));
  });

  testWidgets('글 바깥을 끌면 글이 그대로 밀린다', (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      host(fraction: .5, onResized: (_) {}, scroll: scroll),
    );
    await tester.drag(find.byKey(const Key('media')), const Offset(0, -200));
    await tester.pump();
    expect(scroll.offset, greaterThan(100));
  });
}
