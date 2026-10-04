import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../models/attachment.dart';
import '../models/memo.dart';
import 'when.dart';

/// 첨부를 글 사이에 남기는 한 줄. 파일 자체는 공유 창에 따로 실려 가므로,
/// 여기서는 어느 줄 아래에 있던 것인지만 알린다.
String attachmentLine(Attachment a, [AppLocale locale = AppLocale.ko]) {
  final label = switch (a.kind) {
    'image' => trLocale(
      locale,
      '사진',
      en: 'Photo',
      zh: '照片',
      fr: 'Photo',
      ja: '写真',
    ),
    'video' => trLocale(
      locale,
      '동영상',
      en: 'Video',
      zh: '视频',
      fr: 'Vidéo',
      ja: '動画',
    ),
    _ => trLocale(
      locale,
      '파일',
      en: 'File',
      zh: '文件',
      fr: 'Fichier',
      ja: 'ファイル',
    ),
  };
  return '[$label] ${a.name}';
}

/// 카드 한 장을 그대로 읽히는 글로 옮긴다.
///
/// 카카오톡·메시지·메모 어디에 붙여 넣어도 모양이 무너지지 않도록
/// 표는 쓰지 않고 줄 앞 표시만 남긴다. 체크리스트는 한 눈에 보이게
/// 네모를 그대로 옮긴다. 사진·동영상·파일은 놓여 있던 줄 아래에 이름을
/// 한 줄로 남긴다.
String boardAsText(
  Board board,
  List<Entry> entries, {
  List<Attachment> attachments = const [],
  AppLocale locale = AppLocale.ko,
}) {
  final buf = StringBuffer(board.title);
  if (board.subtitle.isNotEmpty) buf.write('\n${board.subtitle}');
  buf.write(
    '\n${trLocale(locale, '${ymdhm(board.createdAt, locale)}에 시작한 메모', en: 'Started ${ymdhm(board.createdAt, locale)}', zh: '${ymdhm(board.createdAt, locale)} 开始的备忘录', fr: 'Note débutée le ${ymdhm(board.createdAt, locale)}', ja: '${ymdhm(board.createdAt, locale)}に始めたメモ')}',
  );

  final live = entries.map((e) => e.id).toSet();
  final atEnd = attachments
      .where((a) => a.afterEntryId == null || !live.contains(a.afterEntryId))
      .toList();
  final written = entries.where((e) => e.text.trim().isNotEmpty).toList();
  if (written.isEmpty && attachments.isEmpty) {
    buf.write(
      '\n\n(${trLocale(locale, '아직 적은 것이 없어요', en: 'Nothing written yet', zh: '还没有写下任何内容', fr: 'Rien d’écrit pour le moment', ja: 'まだ何も書かれていません')})',
    );
    return buf.toString();
  }
  buf.write('\n');
  for (final e in entries) {
    if (e.text.trim().isNotEmpty) {
      final bullet = switch (board.kind) {
        BoardKind.checklist => e.checked ? '☑' : '☐',
        BoardKind.hearts => '♡',
        BoardKind.note => '·',
      };
      buf.write('\n$bullet ${e.text.trim()}');
    }
    for (final a in attachments.where((a) => a.afterEntryId == e.id)) {
      buf.write('\n  ${attachmentLine(a, locale)}');
    }
  }
  for (final a in atEnd) {
    buf.write('\n${attachmentLine(a, locale)}');
  }
  return buf.toString();
}

/// 공유 창에 함께 실어 보낼 파일과, 받는 앱에 보일 이름.
///
/// 저장된 파일 이름은 번호라서 그대로 보내면 메모 앱에 `01a0…jpg` 로
/// 남는다. 붙여 넣은 원래 이름으로 바꿔 보내고, 이름이 겹치면 (2) 를
/// 붙인다. 지금 기기에 없는 파일은 건너뛴다.
({List<XFile> files, List<String> names}) shareFilesOf(
  List<Attachment> attachments,
  File Function(Attachment) fileOf,
) {
  final files = <XFile>[];
  final names = <String>[];
  final used = <String>{};
  for (final a in attachments) {
    final file = fileOf(a);
    if (!file.existsSync()) continue;
    var name = a.name.isEmpty ? a.storageName : a.name;
    if (!used.add(name.toLowerCase())) {
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      var n = 2;
      while (!used.add('$stem ($n)$ext'.toLowerCase())) {
        n++;
      }
      name = '$stem ($n)$ext';
    }
    files.add(XFile(file.path, mimeType: _mimeOf(a.storageName), name: name));
    names.add(name);
  }
  return (files: files, names: names);
}

/// 아이폰은 jpg·png 만 사진으로 받고 나머지는 파일로 받는다. 형식을 알려
/// 줘야 사진이 메모 안에 사진으로 놓인다.
String _mimeOf(String storageName) {
  final dot = storageName.lastIndexOf('.');
  final ext = dot < 0 ? '' : storageName.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'webp' => 'image/webp',
    'mov' => 'video/quicktime',
    'mp4' || 'm4v' => 'video/mp4',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

/// 카드 한 장을 OS 공유 시트로 넘긴다. 사진·동영상·파일도 함께 실린다.
Future<void> shareBoard(
  Board board,
  List<Entry> entries, {
  List<Attachment> attachments = const [],
  File Function(Attachment)? fileOf,
  AppLocale locale = AppLocale.ko,
}) {
  final sent = fileOf == null
      ? (files: <XFile>[], names: <String>[])
      : shareFilesOf(attachments, fileOf);
  return SharePlus.instance.share(
    ShareParams(
      text: boardAsText(
        board,
        entries,
        attachments: attachments,
        locale: locale,
      ),
      subject: board.title,
      files: sent.files.isEmpty ? null : sent.files,
      fileNameOverrides: sent.files.isEmpty ? null : sent.names,
    ),
  );
}

/// 내보낼 것이 있는 카드만 추린다. 적은 줄도 첨부도 없는 카드는 '아직 적은
/// 것이 없어요' 한 줄만 남아 받는 쪽을 어지럽히기만 한다.
List<Board> boardsWithContent(
  List<Board> boards,
  List<Entry> Function(String boardId) entriesOf,
  List<Attachment> Function(String boardId)? attachmentsOf,
) => boards
    .where(
      (b) =>
          entriesOf(b.id).any((e) => e.text.trim().isNotEmpty) ||
          (attachmentsOf?.call(b.id).isNotEmpty ?? false),
    )
    .toList();

/// 가진 메모를 모두 한 덩이 글로 옮긴다.
///
/// 애플은 다른 앱이 메모 앱에 글을 써 넣는 길을 열어 두지 않았다. 그래서
/// 공유 창에 글을 넘기고, 받는 곳으로 '메모'를 고르게 한다. 고른 순간
/// 메모 앱에 새 메모 한 장이 그대로 만들어진다.
String allBoardsAsText(
  List<Board> boards,
  List<Entry> Function(String boardId) entriesOf, {
  List<Attachment> Function(String boardId)? attachmentsOf,
  AppLocale locale = AppLocale.ko,
}) {
  boards = boardsWithContent(boards, entriesOf, attachmentsOf);
  final buf =
      StringBuffer(
          trLocale(
            locale,
            'Cosmeow',
            en: 'Cosmeow',
            zh: 'Cosmeow',
            fr: 'Cosmeow',
            ja: 'Cosmeow',
          ),
        )
        ..write(
          '\n${trLocale(locale, '${ymdhm(DateTime.now(), locale)} 내보냄', en: 'Exported ${ymdhm(DateTime.now(), locale)}', zh: '${ymdhm(DateTime.now(), locale)} 导出', fr: 'Exporté le ${ymdhm(DateTime.now(), locale)}', ja: '${ymdhm(DateTime.now(), locale)} に書き出し')}',
        )
        ..write(
          '\n${trLocale(locale, '메모 ${boards.length}장', en: '${boards.length} memos', zh: '${boards.length} 篇备忘录', fr: '${boards.length} notes', ja: 'メモ${boards.length}枚')}',
        );
  for (final board in boards) {
    buf.write('\n\n────────\n');
    buf.write(
      boardAsText(
        board,
        entriesOf(board.id),
        attachments: attachmentsOf?.call(board.id) ?? const [],
        locale: locale,
      ),
    );
  }
  return buf.toString();
}

/// 보낼 카드가 하나도 없으면 공유 창을 열지 않고 false 를 돌려준다.
Future<bool> shareAllBoards(
  List<Board> boards,
  List<Entry> Function(String boardId) entriesOf, {
  List<Attachment> Function(String boardId)? attachmentsOf,
  File Function(Attachment)? fileOf,
  AppLocale locale = AppLocale.ko,
}) async {
  boards = boardsWithContent(boards, entriesOf, attachmentsOf);
  if (boards.isEmpty) return false;
  final all = <Attachment>[
    if (attachmentsOf != null)
      for (final b in boards) ...attachmentsOf(b.id),
  ];
  final sent = fileOf == null
      ? (files: <XFile>[], names: <String>[])
      : shareFilesOf(all, fileOf);
  await SharePlus.instance.share(
    ShareParams(
      text: allBoardsAsText(
        boards,
        entriesOf,
        attachmentsOf: attachmentsOf,
        locale: locale,
      ),
      subject: trLocale(
        locale,
        'Cosmeow',
        en: 'Cosmeow',
        zh: 'Cosmeow',
        fr: 'Cosmeow',
        ja: 'Cosmeow',
      ),
      files: sent.files.isEmpty ? null : sent.files,
      fileNameOverrides: sent.files.isEmpty ? null : sent.names,
    ),
  );
  return true;
}
