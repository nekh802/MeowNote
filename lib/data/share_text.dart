import 'package:share_plus/share_plus.dart';

import '../models/memo.dart';
import 'when.dart';

/// 카드 한 장을 그대로 읽히는 글로 옮긴다.
///
/// 카카오톡·메시지·메모 어디에 붙여 넣어도 모양이 무너지지 않도록
/// 표는 쓰지 않고 줄 앞 표시만 남긴다. 체크리스트는 한 눈에 보이게
/// 네모를 그대로 옮긴다.
String boardAsText(Board board, List<Entry> entries) {
  final buf = StringBuffer(board.title);
  if (board.subtitle.isNotEmpty) buf.write('\n${board.subtitle}');
  buf.write('\n${ymdhm(board.createdAt)}에 시작한 메모');

  final written = entries.where((e) => e.text.trim().isNotEmpty).toList();
  if (written.isEmpty) {
    buf.write('\n\n(아직 적은 것이 없어요)');
  } else {
    buf.write('\n');
    for (final e in written) {
      final bullet = switch (board.kind) {
        BoardKind.checklist => e.checked ? '☑' : '☐',
        BoardKind.hearts => '♡',
        BoardKind.note => '·',
      };
      buf.write('\n$bullet ${e.text.trim()}');
    }
  }
  return buf.toString();
}

/// 카드 한 장을 OS 공유 시트로 넘긴다.
Future<void> shareBoard(Board board, List<Entry> entries) =>
    SharePlus.instance.share(
      ShareParams(text: boardAsText(board, entries), subject: board.title),
    );

/// 앱 자체를 친구에게 건네는 링크.
///
/// 애플은 앱 안에서 앱을 선물하는 길을 열어 두지 않았다. 인앱결제로
/// 남에게 앱을 사 줄 수도 없다. 대신 앱스토어 페이지를 건네면, 받은
/// 사람이 그 자리에서 내려받거나 애플의 '앱 선물하기'를 쓸 수 있다.
Future<void> shareGift(Uri page) => SharePlus.instance.share(
  ShareParams(text: '말랑 고양이 메모를 선물할게요 🎁\n$page', subject: '말랑 고양이 메모'),
);
