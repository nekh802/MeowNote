import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmeow_note/data/memo_store.dart';
import 'package:cosmeow_note/models/attachment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'imports duplicate names separately, persists, removes and restores',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meow-attachments-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      final store = MemoStore.instance;
      try {
        await store.load();
        final board = store.boards.first;
        for (var i = 0; i < 2; i++) {
          await store.addAttachment(
            boardId: board.id,
            name: '같은 이름.pdf',
            kind: 'file',
            bytes: Stream.value([1, 2, i]),
          );
        }
        final items = store.attachmentsOf(board.id);
        expect(items, hasLength(2));
        expect(items.first.storageName, isNot(items.last.storageName));
        expect(await store.attachmentFile(items.first).readAsBytes(), [
          1,
          2,
          0,
        ]);
        store.setAttachmentDeleted(items.first, true);
        expect(store.attachmentsOf(board.id), hasLength(1));
        store.setAttachmentDeleted(items.first, false);
        await Future.wait([store.flush(), store.flush()]);
        final saved = jsonDecode(
          await File('${directory.path}/memo_store.json').readAsString(),
        );
        final restored = (saved['attachments'] as List)
            .map((j) => Attachment.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        expect(restored, hasLength(2));
        expect(restored.first.deleted, false);
        expect(await store.attachmentFile(restored.first).readAsBytes(), [
          1,
          2,
          0,
        ]);
        await expectLater(
          store.addAttachment(
            boardId: board.id,
            name: 'failed.bin',
            kind: 'file',
            bytes: Stream<List<int>>.error(
              const FileSystemException('read failed'),
            ),
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(store.attachmentsOf(board.id), hasLength(2));
        expect(
          await Directory('${directory.path}/attachments').list().length,
          2,
        );
      } finally {
        await store.flush();
        store.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('rejects metadata pointing outside attachment directory', () {
    expect(
      () => Attachment.fromJson({
        'id': 'id',
        'boardId': 'board',
        'name': 'file',
        'storageName': '../memo_store.json',
        'kind': 'file',
        'size': 1,
      }),
      throwsFormatException,
    );
  });
}
