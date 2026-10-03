import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("예전 판을 쓰던 기기는 '소소한 행복' 대신 '기분 좋은 시작'을 기본으로 붙박는다", () async {
    final directory = await Directory.systemTemp.createTemp('meow-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String title, String? pinnedAt) => {
      'id': id,
      'title': title,
      'subtitle': '',
      'colorKey': 'blossom',
      'catId': 'ujoo',
      'badgeKey': 'heart',
      'pose': 'peekBottom',
      'kind': 'note',
      'order': 0,
      'createdAt': now,
      'updatedAt': now,
      'deletedAt': null,
      'pinnedAt': pinnedAt,
    };
    final file = File('${directory.path}/memo_store.json');
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'settings': {'seedSets': 3, 'fixups': 0},
        'boards': [
          board('b1', '소소한 행복', now), // 예전 기본대로 붙박여 있다.
          board('b2', '기분 좋은 시작', null), // 아직 안 붙박여 있다.
          board('b3', '하나씩 해볼까', now), // 계속 붙박이인 카드는 그대로.
        ],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.pinnedAt, isNull); // 소소한 행복 -> 뗐다.
      expect(byId['b2']!.pinnedAt, isNotNull); // 기분 좋은 시작 -> 붙박았다.
      expect(byId['b3']!.pinnedAt, isNotNull); // 하나씩 해볼까 -> 그대로.
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
