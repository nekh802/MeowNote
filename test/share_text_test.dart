import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/share_text.dart';
import 'package:malang_cat/models/memo.dart';

void main() {
  test('내보내는 글에 시작한 때와 줄 앞 표시가 함께 담긴다', () {
    final board = Board.create(
      title: '하나씩 해볼까',
      subtitle: '오늘의 작은 목표',
      colorKey: 'apricot',
      catId: 'dalgi',
      kind: BoardKind.checklist,
      order: 0,
    );
    final entries = [
      Entry.create(boardId: board.id, text: '책 읽기', checked: true, order: 0),
      Entry.create(boardId: board.id, text: '산책하기', order: 1),
      Entry.create(boardId: board.id, text: '   ', order: 2),
    ];

    final text = boardAsText(board, entries);
    final at = board.createdAt.toLocal();

    expect(text, startsWith('하나씩 해볼까\n오늘의 작은 목표\n'));
    expect(text, contains('${at.year}년 ${at.month}월 ${at.day}일'));
    expect(text, contains('에 시작한 메모'));
    expect(text, contains('☑ 책 읽기'));
    expect(text, contains('☐ 산책하기'));
    // 빈 줄은 내보내지 않는다.
    expect(text.split('\n').where((l) => l.trim() == '☐').isEmpty, isTrue);
  });
}
