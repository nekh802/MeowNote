import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('예전 판을 쓰던 기기는 기본 카드를 우주 고양이로 옮긴다', () async {
    final directory = await Directory.systemTemp.createTemp('meow-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    // 옛 기본 고양이(mochi)로 저장된 파일을 흉내 낸다.
    final file = File('${directory.path}/memo_store.json');
    final now = DateTime.now().toUtc().toIso8601String();
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'settings': {'seedSets': 3, 'fixups': 0},
        'boards': [
          {
            'id': 'b1',
            'title': '오늘의 메모',
            'subtitle': '',
            'colorKey': 'blossom',
            'catId': 'mochi',
            'badgeKey': 'heart',
            'pose': 'peekTop',
            'kind': 'note',
            'order': 0,
            'createdAt': now,
            'updatedAt': now,
            'deletedAt': null,
            'pinnedAt': null,
          },
        ],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.catId, 'ujoo'); // 기본 그대로 -> 우주 고양이로 옮겨졌다.
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
