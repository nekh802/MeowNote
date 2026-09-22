import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("'하나씩 해볼까'는 별똥에서 달빛으로 한 번 더 옮기고, 직접 고른 고양이는 지킨다", () async {
    final directory = await Directory.systemTemp.createTemp('malang-seed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> board(String id, String cat) => {
      'id': id,
      'title': '하나씩 해볼까',
      'subtitle': '',
      'colorKey': 'apricot',
      'catId': cat,
      'badgeKey': 'sprout',
      'pose': 'peekBottom',
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
        // b1 은 별똥(옛 기본) 그대로, b2 는 사용자가 직접 다른 아이(초코)로
        // 바꿔 둔 것으로 흉내 낸다.
        'boards': [board('b1', 'byeoltong'), board('b2', 'choco')],
        'entries': [],
      }),
    );
    final store = MemoStore.instance;
    try {
      await store.load();
      final byId = {for (final b in store.boards) b.id: b};
      expect(byId['b1']!.catId, 'dalbit');
      expect(byId['b2']!.catId, 'choco');
    } finally {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    }
  });
}
