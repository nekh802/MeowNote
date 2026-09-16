import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 기기에서 만드는 식별자. v7은 시간순으로 정렬되므로 인덱스가 조각나지
/// 않고, 서버 채번을 기다릴 필요가 없어 오프라인에서도 바로 생성된다.
/// 백업 복원 시 중복 판정의 유일한 기준이기도 하다.
String newId() => _uuid.v7();

DateTime _now() => DateTime.now().toUtc();

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime _parse(Object? v) =>
    v == null ? _now() : DateTime.parse(v as String).toUtc();
DateTime? _parseOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

/// 카드 한 장의 성격.
enum BoardKind {
  /// 줄글 — 줄 앞에 아무것도 없다.
  note,

  /// 할 일 목록 — 줄 앞에 네모 칸.
  checklist,

  /// 줄 앞에 작은 하트. 두 번째 장의 '기분 좋은 시작', '마음 비우기'.
  hearts,
}

/// 고양이가 카드 어디에 어떻게 앉는지.
///
/// 컨셉아트에서 카드마다 자세가 달라 리듬이 생기므로, 배치도
/// 카드의 데이터로 다룬다.
enum CatPose {
  /// 카드 위쪽 모서리에 걸터앉아 아래를 내려다본다.
  peekTop,

  /// 카드 아래쪽 오른편에서 빼꼼 올라온다.
  peekBottom,

  /// 카드 아래쪽 왼편에서 빼꼼 올라온다.
  peekLeft,

  /// 카드 안쪽에 크게, 아주 옅게 깔린다.
  watermark,

  /// 세 마리가 나란히 아래쪽에 앉는다.
  trio,

  /// 고양이 없음.
  none,
}

/// 목록에서 카드를 늘어놓는 차례.
enum BoardSort {
  /// 마지막으로 손댄 것이 맨 앞. 기본값 — 쓰던 메모를 다시 찾기 쉽다.
  edited,

  /// 처음 만든 것이 맨 앞.
  created,

  /// 제목 가나다·ABC 순.
  name,
}

/// 화면에 놓이는 메모 카드 한 장.
class Board {
  Board({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.colorKey,
    required this.catId,
    required this.badgeKey,
    required this.pose,
    required this.kind,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.pinnedAt,
  });

  final String id;
  String title;
  String subtitle;
  String colorKey;
  String catId;
  String badgeKey;
  CatPose pose;
  BoardKind kind;
  int order;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  /// 목록 맨 위에 붙박아 둔 때. 안 붙였으면 null.
  DateTime? pinnedAt;

  bool get isAlive => deletedAt == null;
  bool get isPinned => pinnedAt != null;

  void touch() => updatedAt = _now();

  factory Board.create({
    required String title,
    String subtitle = '',
    required String colorKey,
    required String catId,
    String badgeKey = 'heart',
    CatPose pose = CatPose.peekBottom,
    BoardKind kind = BoardKind.note,
    required int order,
  }) {
    final now = _now();
    return Board(
      id: newId(),
      title: title,
      subtitle: subtitle,
      colorKey: colorKey,
      catId: catId,
      badgeKey: badgeKey,
      pose: pose,
      kind: kind,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'colorKey': colorKey,
    'catId': catId,
    'badgeKey': badgeKey,
    'pose': pose.name,
    'kind': kind.name,
    'order': order,
    'createdAt': _iso(createdAt),
    'updatedAt': _iso(updatedAt),
    'deletedAt': _iso(deletedAt),
    'pinnedAt': _iso(pinnedAt),
  };

  factory Board.fromJson(Map<String, dynamic> j) => Board(
    id: j['id'] as String,
    title: (j['title'] ?? '') as String,
    subtitle: (j['subtitle'] ?? '') as String,
    colorKey: (j['colorKey'] ?? 'blossom') as String,
    catId: (j['catId'] ?? 'mochi') as String,
    badgeKey: (j['badgeKey'] ?? 'heart') as String,
    pose: CatPose.values.firstWhere(
      (p) => p.name == j['pose'],
      orElse: () => CatPose.peekBottom,
    ),
    kind: BoardKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => BoardKind.note,
    ),
    order: (j['order'] ?? 0) as int,
    createdAt: _parse(j['createdAt']),
    updatedAt: _parse(j['updatedAt']),
    deletedAt: _parseOrNull(j['deletedAt']),
    pinnedAt: _parseOrNull(j['pinnedAt']),
  );
}

/// 카드 안의 한 줄.
class Entry {
  Entry({
    required this.id,
    required this.boardId,
    required this.text,
    required this.checked,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String boardId;
  String text;
  bool checked;
  int order;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  bool get isAlive => deletedAt == null;

  void touch() => updatedAt = _now();

  factory Entry.create({
    required String boardId,
    String text = '',
    bool checked = false,
    required int order,
  }) {
    final now = _now();
    return Entry(
      id: newId(),
      boardId: boardId,
      text: text,
      checked: checked,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'boardId': boardId,
    'text': text,
    'checked': checked,
    'order': order,
    'createdAt': _iso(createdAt),
    'updatedAt': _iso(updatedAt),
    'deletedAt': _iso(deletedAt),
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    boardId: j['boardId'] as String,
    text: (j['text'] ?? '') as String,
    checked: (j['checked'] ?? false) as bool,
    order: (j['order'] ?? 0) as int,
    createdAt: _parse(j['createdAt']),
    updatedAt: _parse(j['updatedAt']),
    deletedAt: _parseOrNull(j['deletedAt']),
  );
}
