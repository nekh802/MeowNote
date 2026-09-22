import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('처음 까는 기기는 기본 카드 열두 장을 모두 우주 고양이로 받는다', () async {
    final directory = await Directory.systemTemp.createTemp('malang-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final store = MemoStore.instance;
    try {
      await store.load();
      final live = store.boards.where((b) => b.isAlive).toList();
      expect(live, hasLength(12));
      const space = {
        'ujoo',
        'byeoltong',
        'dalbit',
        'eunha',
        'choco',
        'pyeonji',
        'cho',
        'byeol2',
        'usubu',
        'got',
        'rocket',
        'byeoljari',
        'nakksi',
        'yuribyeong',
        'wiseong',
        'pungseon',
        'haemak',
        'byeolit',
      };
      for (final b in live) {
        expect(
          space.contains(b.catId),
          isTrue,
          reason: '${b.title}: ${b.catId}',
        );
      }
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
