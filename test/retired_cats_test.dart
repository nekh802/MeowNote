import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('처음 만들었던 고양이나 세 마리 그림을 쓰던 카드는 직접 고른 것이라도 우주 고양이로 옮긴다', () async {
    final directory = await Directory.systemTemp.createTemp('meow-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
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
    final file = File('${directory.path}/memo_store.json');
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(
      String id,
      String title,
      String cat,
      String pose,
    ) => {
      'id': id,
      'title': title,
      'subtitle': '',
      'colorKey': 'butter',
      'catId': cat,
      'badgeKey': 'heart',
      'pose': pose,
      'kind': 'note',
      'order': 0,
      'createdAt': now,
      'updatedAt': now,
      'deletedAt': null,
      'pinnedAt': null,
    };
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'settings': {'seedSets': 3, 'fixups': 0},
        'boards': [
          // 사용자가 만든 카드에서 옛 고양이를 직접 골라 둔 경우.
          board('b1', '나에게 한마디', 'byeol', 'peekBottom'),
          // 세 마리 그림을 골라 둔 경우 — 자리도 정상 자리로 바뀐다.
          board('b2', '내가 만든 메모', 'mochi', 'trio'),
          // 이미 우주 고양이를 골라 둔 카드는 그대로 둔다.
          board('b3', '또 다른 메모', 'choco', 'peekLeft'),
        ],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(space.contains(byId['b1']!.catId), isTrue);
      expect(space.contains(byId['b2']!.catId), isTrue);
      expect(byId['b2']!.pose.name, isNot('trio'));
      expect(byId['b3']!.catId, 'choco'); // 이미 우주 고양이 -> 그대로.
      expect(byId['b3']!.pose.name, 'peekLeft');
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
