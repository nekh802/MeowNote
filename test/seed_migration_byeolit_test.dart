import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("'차분히 정리하기'는 위성에서 별잇기로 한 번 더 옮기고, 직접 고른 고양이는 지킨다", () async {
    final directory = await Directory.systemTemp.createTemp('meow-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String cat) => {
      'id': id,
      'title': '차분히 정리하기',
      'subtitle': '',
      'colorKey': 'lilac',
      'catId': cat,
      'badgeKey': 'spark',
      'pose': 'watermark',
      'kind': 'checklist',
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
        // b1 은 위성(옛 기본) 그대로, b2 는 사용자가 직접 다른 아이(낚시)로
        // 바꿔 둔 것으로 흉내 낸다.
        'boards': [board('b1', 'wiseong'), board('b2', 'nakksi')],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.catId, 'byeolit');
      expect(byId['b2']!.catId, 'nakksi');
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
