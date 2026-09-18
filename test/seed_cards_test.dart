import 'package:flutter_test/flutter_test.dart';
import 'package:malang_cat/data/memo_store.dart';
import 'package:malang_cat/models/memo.dart';
import 'package:malang_cat/theme/palette.dart';
import 'package:malang_cat/widgets/cat_face.dart';

/// 앱을 처음 깔면 놓이는 카드들.
///
/// 이 열한 장은 앱을 켜자마자 눈에 들어오는 첫인상이라, 한 장을 손보다
/// 옆 장이 함께 어긋나는 일이 없도록 구성을 통째로 적어 둔다. 여기가
/// 어긋나면 바꾼 쪽이 맞는지 이 표를 보고 정한다.
void main() {
  const seeded = <(String, String, String, String, String, CatPose, BoardKind)>[
    // 컨셉아트 첫 장.
    (
      '오늘의 메모',
      '',
      'mochi',
      'blossom',
      'heart',
      CatPose.peekTop,
      BoardKind.note,
    ),
    (
      '하나씩 해볼까',
      '',
      'dalgi',
      'apricot',
      'sprout',
      CatPose.peekBottom,
      BoardKind.checklist,
    ),
    (
      '잠깐 쉬어가기',
      '천천히 해도 괜찮아',
      'byeol',
      'sky',
      'moon',
      CatPose.watermark,
      BoardKind.note,
    ),
    ('문득 떠오른 생각', '', 'sol', 'lilac', 'bulb', CatPose.peekLeft, BoardKind.note),
    (
      '오늘의 기분',
      '',
      'haneul',
      'mint',
      'smile',
      CatPose.peekBottom,
      BoardKind.note,
    ),
    (
      '나에게 한마디',
      '오늘도 잘했어',
      'kongi',
      'butter',
      'heart',
      CatPose.peekBottom,
      BoardKind.note,
    ),
    // 두 번째 이야기.
    (
      '기분 좋은 시작',
      '오늘의 작은 목표',
      'haneul',
      'sky',
      'spark',
      CatPose.trio,
      BoardKind.hearts,
    ),
    (
      '번뜩인 아이디어',
      '',
      'bori',
      'apricot',
      'bulb',
      CatPose.peekLeft,
      BoardKind.note,
    ),
    (
      '차분히 정리하기',
      '',
      'mongi',
      'lilac',
      'spark',
      CatPose.watermark,
      BoardKind.checklist,
    ),
    (
      '괜찮아, 천천히',
      '하나씩 해도 괜찮아',
      'dalrae',
      'mint',
      'none',
      CatPose.peekTop,
      BoardKind.note,
    ),
    (
      '내일 또 만나',
      '내일의 나에게 남기는 말',
      'danchu',
      'butter',
      'heart',
      CatPose.peekTop,
      BoardKind.note,
    ),
  ];

  final store = MemoStore.instance;

  setUp(store.debugSeed);

  test('갓 깐 기기에는 이 열한 장이 이 차례로 놓인다', () {
    final got = store.boards
        .map(
          (b) => (
            b.title,
            b.subtitle,
            b.catId,
            b.colorKey,
            b.badgeKey,
            b.pose,
            b.kind,
          ),
        )
        .toList();
    expect(got, seeded);
  });

  test('할 일 카드에는 시작할 거리가 세 줄 들어 있다', () {
    // 체크 카드가 텅 비어 있으면 무엇을 하는 카드인지 보이지 않는다.
    final board = store.boards.firstWhere((b) => b.title == '하나씩 해볼까');
    expect(store.entriesOf(board.id).map((e) => e.text), [
      '책 읽기',
      '산책하기',
      '메모 정리',
    ]);

    // 나머지 카드는 빈 채로 놓여 처음 쓰는 사람이 채운다.
    for (final other in store.boards.where((b) => b.id != board.id)) {
      expect(store.entriesOf(other.id), isEmpty, reason: other.title);
    }
  });

  test('기본 카드가 고르는 색과 고양이와 표시는 모두 실제로 있는 것이다', () {
    for (final board in store.boards) {
      expect(
        CardPalette.all.any((p) => p.key == board.colorKey),
        isTrue,
        reason: '${board.title} 의 색 ${board.colorKey}',
      );
      expect(
        CatSpec.all.any((c) => c.id == board.catId),
        isTrue,
        reason: '${board.title} 의 고양이 ${board.catId}',
      );
      expect(
        CardBadge.all.any((b) => b.key == board.badgeKey),
        isTrue,
        reason: '${board.title} 의 표시 ${board.badgeKey}',
      );
    }
  });

  test('갓 깐 기기에는 지운 흔적이 없다', () {
    // 걷어낸 카드는 쓰던 기기에서만 흔적으로 남는다. 처음 까는 기기까지
    // 그 흔적을 들고 시작할 이유는 없다.
    expect(store.boards.every((b) => b.deletedAt == null), isTrue);
  });
}
