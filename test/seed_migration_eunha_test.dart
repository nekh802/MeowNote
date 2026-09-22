import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("'소소한 행복'은 우주복에서 은하로 한 번 더 옮기고, 직접 고른 고양이는 지킨다", () async {
    final directory = await Directory.systemTemp.createTemp('malang-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String cat) => {
      'id': id,
      'title': '소소한 행복',
      'subtitle': '오늘 나를 웃게 한 것',
      'colorKey': 'blossom',
      'catId': cat,
      'badgeKey': 'paw',
      'pose': 'peekTop',
      'kind': 'hearts',
      'order': 0,
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
        // b1 은 우주복(옛 기본) 그대로, b2 는 사용자가 직접 다른 아이(고리)로
        // 바꿔 둔 것으로 흉내 낸다.
        'boards': [board('b1', 'usubu'), board('b2', 'got')],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.catId, 'eunha');
      expect(byId['b2']!.catId, 'got');
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
