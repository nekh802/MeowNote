import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_note/data/memo_store.dart';
import 'package:meow_note/data/share_text.dart';
import 'package:meow_note/models/attachment.dart';
import 'package:meow_note/models/memo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('메모 안에 놓인 첨부', () {
    late Directory directory;
    late MemoStore store;
    late Board board;

    Future<Attachment> add(String name, String kind, {String? after}) async {
      await store.addAttachment(
        boardId: board.id,
        name: name,
        kind: kind,
        bytes: Stream.value([1, 2, 3]),
        afterEntryId: after,
      );
      return store.attachmentsOf(board.id).firstWhere((a) => a.name == name);
    }

    // 저장소는 하나뿐이라 한 번만 열고, 시험마다 새 카드를 쓴다. 시험마다
    // 닫으면 지워진 임시 폴더를 다시 가리켜 두 번째부터 깨진다.
    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('malang-inline-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      store = MemoStore.instance;
      await store.load();
    });

    setUp(() {
      board = store.addBoard(colorKey: 'blossom', catId: 'mochi');
    });

    tearDownAll(() async {
      await store.flush();
      store.dispose();
      await directory.delete(recursive: true);
    });

    test('놓인 줄 바로 아래에 나오고, 줄이 없으면 글 맨 끝에 나온다', () async {
      final first = store.addEntry(board.id);
      final second = store.addEntry(board.id);
      final photo = await add('a.jpg', 'image', after: first.id);
      final loose = await add('b.mov', 'video');
      expect(store.attachmentsAfter(board.id, first.id), [photo]);
      expect(store.attachmentsAfter(board.id, second.id), isEmpty);
      expect(store.attachmentsAtEnd(board.id), [loose]);
    });

    test('커서가 있던 줄을 기억해, 그 줄이 남아 있을 때만 그 아래에 놓는다', () async {
      final first = store.addEntry(board.id);
      final second = store.addEntry(board.id);
      expect(store.entryForNewAttachment(board.id), isNull);
      store.rememberFocusedEntry(board.id, first.id);
      expect(store.entryForNewAttachment(board.id), first.id);
      store.rememberFocusedEntry(board.id, second.id);
      store.deleteEntry(second.id);
      // 기억해 둔 줄이 지워졌으면 맨 끝으로 간다.
      expect(store.entryForNewAttachment(board.id), isNull);
    });

    test('줄을 지우면 그 아래 사진은 윗 줄 아래에 남는다', () async {
      final first = store.addEntry(board.id);
      final second = store.addEntry(board.id);
      final photo = await add('a.jpg', 'image', after: second.id);
      store.deleteEntry(second.id);
      expect(photo.afterEntryId, first.id);
      expect(store.attachmentsAfter(board.id, first.id), [photo]);
    });

    test('첫 줄을 지우면 아래 사진은 글 맨 끝으로 간다', () async {
      final first = store.addEntry(board.id);
      final photo = await add('a.jpg', 'image', after: first.id);
      store.deleteEntry(first.id);
      expect(photo.afterEntryId, isNull);
      expect(store.attachmentsAtEnd(board.id), [photo]);
    });

    test('크기는 한계 안으로 묶이고 파일에 저장돼 다시 열어도 남는다', () async {
      final first = store.addEntry(board.id);
      final photo = await add('a.jpg', 'image', after: first.id);
      expect(photo.widthFraction, Attachment.defaultWidth);
      store.setAttachmentLayout(photo, widthFraction: .35);
      expect(photo.widthFraction, .35);
      store.setAttachmentLayout(photo, widthFraction: 9);
      expect(photo.widthFraction, Attachment.maxWidth);
      store.setAttachmentLayout(photo, widthFraction: .01);
      expect(photo.widthFraction, Attachment.minWidth);
      store.setAttachmentLayout(photo, widthFraction: .5);
      await store.flush();

      final saved = jsonDecode(
        await File('${directory.path}/memo_store.json').readAsString(),
      );
      final back = (saved['attachments'] as List)
          .map((j) => Attachment.fromJson(Map<String, dynamic>.from(j)))
          .firstWhere((a) => a.id == photo.id);
      expect(back.widthFraction, .5);
      expect(back.afterEntryId, first.id);
    });

    test('옛 파일에는 놓인 줄과 크기가 없어도 읽힌다', () {
      final a = Attachment.fromJson({
        'id': 'x',
        'boardId': 'b',
        'name': 'old.jpg',
        'storageName': 'x.jpg',
        'kind': 'image',
        'size': 10,
      });
      expect(a.afterEntryId, isNull);
      expect(a.widthFraction, Attachment.defaultWidth);
    });
  });

  group('내보내기', () {
    Attachment att(String name, String kind, {String? after, String? file}) =>
        Attachment(
          id: name,
          boardId: 'b',
          name: name,
          storageName: file ?? '$name.bin',
          kind: kind,
          size: 3,
          afterEntryId: after,
        );

    test('글 사이에 사진·동영상·파일 이름이 놓인 자리대로 남는다', () {
      final board = Board.create(
        title: '오늘',
        colorKey: 'blossom',
        catId: 'mochi',
        order: 0,
      );
      final one = Entry.create(boardId: board.id, text: '첫 줄', order: 0);
      final blank = Entry.create(boardId: board.id, text: '', order: 1);
      final two = Entry.create(boardId: board.id, text: '둘째 줄', order: 2);
      final text = boardAsText(
        board,
        [one, blank, two],
        attachments: [
          att('a.jpg', 'image', after: one.id),
          att('clip.mov', 'video', after: blank.id),
          att('보고서.pdf', 'file'),
        ],
      );
      final lines = text.split('\n');
      final i = lines.indexOf('· 첫 줄');
      expect(lines[i + 1], '  [사진] a.jpg');
      // 빈 줄 아래에 놓인 동영상도 잃지 않고 첫 줄과 둘째 줄 사이에 남는다.
      expect(lines[i + 2], '  [동영상] clip.mov');
      expect(lines[i + 3], '· 둘째 줄');
      expect(lines.last, '[파일] 보고서.pdf');
    });

    test('글은 없고 사진만 있어도 아직 적은 것이 없다고 하지 않는다', () {
      final board = Board.create(
        title: '사진첩',
        colorKey: 'blossom',
        catId: 'mochi',
        order: 0,
      );
      final text = boardAsText(board, [], attachments: [att('a.jpg', 'image')]);
      expect(text, contains('[사진] a.jpg'));
      expect(text, isNot(contains('아직 적은 것이 없어요')));
    });

    test('첨부가 없으면 예전과 똑같은 글이다', () {
      final board = Board.create(
        title: '오늘',
        colorKey: 'blossom',
        catId: 'mochi',
        order: 0,
      );
      final e = Entry.create(boardId: board.id, text: '한 줄', order: 0);
      expect(boardAsText(board, [e]), boardAsText(board, [e], attachments: []));
      expect(boardAsText(board, []), contains('아직 적은 것이 없어요'));
    });

    test('공유 창에는 원래 이름으로, 겹치면 (2) 를 붙이고, 없는 파일은 뺀다', () async {
      final dir = await Directory.systemTemp.createTemp('malang-share-');
      addTearDown(() => dir.delete(recursive: true));
      final files = <String, File>{};
      for (final id in ['p1', 'p2', 'gone']) {
        final f = File('${dir.path}/$id');
        if (id != 'gone') f.writeAsBytesSync([1, 2, 3]);
        files[id] = f;
      }
      final list = [
        att('IMG_1.jpg', 'image', file: 'p1.jpg'),
        att('IMG_1.jpg', 'image', file: 'p2.jpg'),
        att('사라짐.mov', 'video', file: 'gone.mov'),
      ];
      final sent = shareFilesOf(list, (a) {
        final id = a.storageName.split('.').first;
        return files[id]!;
      });
      expect(sent.names, ['IMG_1.jpg', 'IMG_1 (2).jpg']);
      expect(sent.files, hasLength(2));
      // 아이폰이 사진으로 받도록 형식을 알려 준다.
      expect(sent.files.first.mimeType, 'image/jpeg');
    });
  });
}
