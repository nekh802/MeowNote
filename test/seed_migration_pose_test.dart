import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';
import 'package:meow_note/models/memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("'소소한 행복'은 기본 그대로일 때만 위에 걸터앉는 자리로 옮기고, 직접 고른 자리는 지킨다", () async {
    final directory = await Directory.systemTemp.createTemp('meow-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String pose) => {
      'id': id,
      'title': '소소한 행복',
      'subtitle': '오늘 나를 웃게 한 것',
      'colorKey': 'blossom',
      'catId': 'usubu',
      'badgeKey': 'paw',
      'pose': pose,
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
        // b1 은 기본 그대로(오른쪽 아래), b2 는 사용자가 직접 다른 자리로
        // 옮겨 둔 것으로 흉내 낸다.
        'boards': [board('b1', 'peekBottom'), board('b2', 'peekLeft')],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.pose, CatPose.peekTop);
      expect(byId['b2']!.pose, CatPose.peekLeft);
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
