/// Attachment metadata. File contents live beside the memo store, not in JSON.
class Attachment {
  Attachment({
    required this.id,
    required this.boardId,
    required this.name,
    required this.storageName,
    required this.kind,
    required this.size,
    this.deleted = false,
    this.afterEntryId,
    this.widthFraction = defaultWidth,
  });

  /// 사진·동영상을 처음 놓을 때 카드 글 너비에서 차지하는 몫.
  static const defaultWidth = .6;

  /// 끌어서 줄일 수 있는 가장 작은 몫과 가장 큰 몫.
  static const minWidth = .2;
  static const maxWidth = 1.0;

  final String id;
  final String boardId;
  final String name;
  final String storageName;
  final String kind;
  final int size;
  bool deleted;

  /// 이 첨부가 놓인 줄. 그 줄 바로 아래에 보인다. 비어 있거나, 지운 줄이면
  /// 글 맨 끝에 놓인다. 옛 파일에는 없어 null 이다.
  String? afterEntryId;

  /// 카드 글 너비에서 차지하는 몫 ([minWidth]~[maxWidth]). 사진과 동영상만
  /// 쓴다 — 파일은 늘 한 줄짜리 카드다.
  double widthFraction;

  /// 사진이나 동영상처럼 메모 안에 그대로 보여 주는 것.
  bool get isMedia => kind == 'image' || kind == 'video';

  Map<String, dynamic> toJson() => {
    'id': id,
    'boardId': boardId,
    'name': name,
    'storageName': storageName,
    'kind': kind,
    'size': size,
    'deleted': deleted,
    'afterEntryId': afterEntryId,
    'widthFraction': widthFraction,
  };

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final storageName = json['storageName'] as String;
    if (!RegExp(r'^[a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9]+)?$').hasMatch(storageName)) {
      throw const FormatException('Invalid attachment filename');
    }
    final width = (json['widthFraction'] as num?)?.toDouble() ?? defaultWidth;
    return Attachment(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      name: json['name'] as String,
      storageName: storageName,
      kind: json['kind'] as String,
      size: json['size'] as int,
      deleted: json['deleted'] == true,
      afterEntryId: json['afterEntryId'] as String?,
      widthFraction: width.clamp(minWidth, maxWidth),
    );
  }
}
