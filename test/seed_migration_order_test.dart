import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("예전 판을 쓰던 기기는 '기분 좋은 시작'과 '하나씩 해볼까'의 차례를 맞바꾼다", () async {
    final directory = await Directory.systemTemp.createTemp('malang-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String title, int order) => {
      'id': id,
      'title': title,
      'subtitle': '',
      'colorKey': 'sky',
      'catId': 'rocket',
      'badgeKey': 'spark',
      'pose': 'peekTop',
      'kind': 'note',
      'order': order,
      'createdAt': now,
      'updatedAt': now,
      'deletedAt': null,
      'pinnedAt': null,
    };
    final file = File('${directory.path}/memo_store.json');
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'settings': {'seedSets': 3, 'fixups': 0},
        // 옛 차례(하나씩 해볼까가 앞)를 흉내 낸다.
        'boards': [board('b1', '하나씩 해볼까', 1), board('b2', '기분 좋은 시작', 6)],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.order, 6); // 하나씩 해볼까 -> 뒤로.
      expect(byId['b2']!.order, 1); // 기분 좋은 시작 -> 앞으로.
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
