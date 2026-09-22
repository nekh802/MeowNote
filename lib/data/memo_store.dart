import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/memo.dart';
import '../l10n.dart';
import '../models/attachment.dart';

/// 로컬 우선 저장소.
///
/// 원본은 항상 이 기기의 파일이고, 서버는 나중에 붙을 중계소다. 그래서
/// 화면은 네트워크를 기다리지 않고, 비행기 모드에서도 전부 동작한다.
/// 모든 레코드가 [Board.updatedAt] / [Board.deletedAt] 을 들고 있어서
/// 나중에 델타 동기화를 그대로 얹을 수 있다.
/// 기본 카드 하나의 번역. 한국어는 seeds 목록에 이미 있어 여기 없다.
class _SeedText {
  const _SeedText({
    required this.enTitle,
    required this.zhTitle,
    this.enSubtitle = '',
    this.zhSubtitle = '',
    this.enLines = const [],
    this.zhLines = const [],
  });
  final String enTitle, zhTitle, enSubtitle, zhSubtitle;
  final List<String> enLines, zhLines;
}

class MemoStore extends ChangeNotifier {
  MemoStore._();

  static final MemoStore instance = MemoStore._();

  static const schemaVersion = 1;
  static const appVersion = '1.9.1';

  final List<Board> _boards = [];
  final List<Entry> _entries = [];
  final List<Attachment> _attachments = [];

  String _backgroundKey = 'coolWhite';
  String _fontKey = 'gamja';

  static const fontOptions = {
    'gamja': 'GamjaFlower',
    'jua': 'Jua',
    'system': '',
  };

  /// 이 기기에 이미 들어온 기본 카드 묶음의 수. 예전 파일에는 없으므로
  /// 첫 묶음만 받은 것으로 본다.
  int _seededSets = seedSets;
  int _fixups = fixups;
  String _deviceId = '';

  /// 스토어에 올라온 판 가운데 이미 한 번 알린 것. 같은 판을 켤 때마다
  /// 다시 묻지 않으려고 적어 둔다.
  String _toldStoreVersion = '';
  DateTime? _toldStoreAt;

  /// 목록에서 카드를 늘어놓는 차례.
  BoardSort _sort = BoardSort.edited;

  /// 이름 순으로 줄 세울 때 어느 글자를 앞에 둘지 정하는 기준. 기기의
  /// 기본 언어가 한국어면 한글이 앞, 아니면 알파벳이 앞이다.
  String _uiLanguage = PlatformDispatcher.instance.locale.languageCode;

  File? _file;
  Timer? _saveTimer;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  String get backgroundKey => _backgroundKey;
  String get fontKey => _fontKey;
  String? get fontFamily => _fontKey == 'system' ? null : fontOptions[_fontKey];
  String get deviceId => _deviceId;
  String get toldStoreVersion => _toldStoreVersion;

  /// 스토어의 새 판을 마지막으로 알린 때. 옛 파일에는 없어 null 이다.
  DateTime? get toldStoreAt => _toldStoreAt;
  BoardSort get sort => _sort;

  @visibleForTesting
  set uiLanguage(String code) => _uiLanguage = code;

  /// 살아 있는 카드만 순서대로.
  ///
  /// 붙박아 둔 카드가 언제나 앞이고, 그 안에서 고른 차례를 따른다.
  List<Board> get boards {
    final alive = _boards.where((b) => b.isAlive).toList();
    alive.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final by = switch (_sort) {
        // 최근에 손댄 것이 앞.
        BoardSort.edited => b.updatedAt.compareTo(a.updatedAt),
        BoardSort.created => a.createdAt.compareTo(b.createdAt),
        BoardSort.name => _byName(a.title, b.title),
      };
      // 한 번도 손대지 않은 기본 카드끼리는 때가 같다. 그럴 때는 처음
      // 놓인 차례를 지켜, 갓 깐 기기에서 카드가 거꾸로 서지 않게 한다.
      return by != 0 ? by : a.order.compareTo(b.order);
    });
    return alive;
  }

  /// 제목으로 줄 세운다.
  ///
  /// 기기 기본 언어가 앞에 온다 — 한국어를 쓰면 한글 제목이 먼저, 영어를
  /// 쓰면 알파벳 제목이 먼저다. 같은 글자끼리는 한글은 글자 코드 순서가
  /// 곧 가나다 순이고, 알파벳은 대소문자를 가리지 않는다.
  int _byName(String a, String b) {
    final ka = _startsHangul(a), kb = _startsHangul(b);
    if (ka != kb) {
      final koreanFirst = _uiLanguage == 'ko';
      return ka == koreanFirst ? -1 : 1;
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static bool _startsHangul(String s) {
    final t = s.trimLeft();
    if (t.isEmpty) return false;
    final c = t.codeUnitAt(0);
    // 완성형 음절과 낱자.
    return (c >= 0xAC00 && c <= 0xD7A3) || (c >= 0x3131 && c <= 0x318E);
  }

  /// 붙박아 둔 카드만, 그리고 나머지만.
  List<Board> get pinnedBoards => boards.where((b) => b.isPinned).toList();
  List<Board> get looseBoards => boards.where((b) => !b.isPinned).toList();

  /// 카드 하나에 속한 살아 있는 줄만 순서대로.
  List<Entry> entriesOf(String boardId) =>
      _entries.where((e) => e.isAlive && e.boardId == boardId).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  // ---------------------------------------------------------------- 불러오기

  Future<void> load() async {
    if (_loaded) return;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    _file = File('${dir.path}/memo_store.json');

    if (await _file!.exists()) {
      try {
        _applyBundle(
          jsonDecode(await _file!.readAsString()) as Map<String, dynamic>,
        );
      } catch (e) {
        // 파일이 깨졌으면 기본 카드로 시작하되, 원본은 지우지 않고 남겨 둔다.
        debugPrint('memo_store.json 읽기 실패 — 기본값으로 시작: $e');
        await _file!.rename('${_file!.path}.broken');
        _seed(locale: platformLocale);
      }
      // 쓰던 기기에도 새로 그린 카드 묶음을 한 번만 얹는다. 적어 둔
      // 메모는 건드리지 않고 뒤에 붙인다.
      if (_seededSets < seedSets) {
        _seed(from: _seededSets, locale: platformLocale);
        _seededSets = seedSets;
      }
      if (_fixups < fixups) {
        _applyFixups();
        _fixups = fixups;
      }
    } else {
      _seed(locale: platformLocale);
    }

    if (_deviceId.isEmpty) _deviceId = newId();
    _loaded = true;
    notifyListeners();
    _scheduleSave();
  }

  void _applyBundle(Map<String, dynamic> j) {
    _boards
      ..clear()
      ..addAll(
        (j['boards'] as List? ?? []).map(
          (e) => Board.fromJson(e as Map<String, dynamic>),
        ),
      );
    _entries
      ..clear()
      ..addAll(
        (j['entries'] as List? ?? []).map(
          (e) => Entry.fromJson(e as Map<String, dynamic>),
        ),
      );
    _attachments
      ..clear()
      ..addAll(
        (j['attachments'] as List? ?? []).map(
          (item) => Attachment.fromJson(item as Map<String, dynamic>),
        ),
      );
    final settings = (j['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    _backgroundKey = (settings['backgroundKey'] ?? 'coolWhite') as String;
    _fontKey = fontOptions.containsKey(settings['fontKey'])
        ? settings['fontKey'] as String
        : 'gamja';
    _seededSets = (settings['seedSets'] ?? 1) as int;
    _fixups = (settings['fixups'] ?? 0) as int;
    _toldStoreVersion = (settings['toldStoreVersion'] ?? '') as String;
    _toldStoreAt = DateTime.tryParse((settings['toldStoreAt'] ?? '') as String);
    _sort = BoardSort.values.firstWhere(
      (s) => s.name == settings['sort'],
      orElse: () => BoardSort.edited,
    );
    _deviceId = (j['deviceId'] ?? '') as String;
  }

  /// 지금까지 넣어 둔 기본 카드 묶음의 수. 이미 쓰던 기기에도 새로 추가된
  /// 묶음이 한 번은 들어오도록 [load] 에서 이 값을 비교한다.
  static const seedSets = 3;

  /// 이미 만들어 둔 카드의 글귀를 손본 횟수. 새 값을 올리면 쓰던 기기에서도
  /// [_applyFixups] 가 한 번 돈다.
  static const fixups = 14;

  /// 처음부터 목록 맨 위에 붙박아 두는 기본 카드의 제목.
  static const pinnedSeeds = {'하나씩 해볼까', '기분 좋은 시작'};

  /// 묶음마다 어디서 시작하는지. 첫 묶음이 여섯 장, 두 번째가 다섯 장,
  /// 세 번째가 한 장이라 한 묶음의 크기로 셈하지 않고 자리를 그대로 적어
  /// 둔다.
  static const _setStarts = [0, 6, 11];

  /// 첫 실행에 놓이는 열두 장. 컨셉아트 두 장의 구성에 '소소한 행복' 한
  /// 장을 더했다 — 한 장은 나중에 걷어냈고, 이미 받아 간 기기에서만
  /// [_applyFixups] 가 흔적으로 남긴다. 고양이는 모두 밤하늘 그림에서 오려 낸
  /// 우주 고양이다. 이 구성은 test/seed_cards_test.dart 가 통째로 지킨다.
  /// 기본 카드 열두 장의 제목·한 줄 설명·체크리스트 줄. 열쇠는 한국어 제목이다.
  static const _seedText = <String, _SeedText>{
    '오늘의 메모': _SeedText(enTitle: "Today's Memo", zhTitle: '今日备忘录'),
    '하나씩 해볼까': _SeedText(
      enTitle: 'One at a Time',
      zhTitle: '一件一件来',
      enLines: ['Read a book', 'Take a walk', 'Tidy notes'],
      zhLines: ['读书', '散步', '整理笔记'],
    ),
    '잠깐 쉬어가기': _SeedText(
      enTitle: 'Take a Breather',
      zhTitle: '稍作休息',
      enSubtitle: "It's okay to take it slow",
      zhSubtitle: '慢慢来也没关系',
    ),
    '문득 떠오른 생각': _SeedText(enTitle: 'A Passing Thought', zhTitle: '忽然想到的'),
    '오늘의 기분': _SeedText(enTitle: "Today's Mood", zhTitle: '今日心情'),
    '나에게 한마디': _SeedText(
      enTitle: 'A Note to Myself',
      zhTitle: '给自己的一句话',
      enSubtitle: 'You did well today',
      zhSubtitle: '今天也辛苦了',
    ),
    '기분 좋은 시작': _SeedText(
      enTitle: 'A Good Start',
      zhTitle: '美好的开始',
      enSubtitle: "Today's small goal",
      zhSubtitle: '今天的小目标',
    ),
    '번뜩인 아이디어': _SeedText(enTitle: 'A Bright Idea', zhTitle: '灵光一闪'),
    '차분히 정리하기': _SeedText(enTitle: 'Sorting Things Out', zhTitle: '静心整理'),
    '괜찮아, 천천히': _SeedText(
      enTitle: "It's Okay, Slowly",
      zhTitle: '没关系，慢慢来',
      enSubtitle: "It's okay to do it one at a time",
      zhSubtitle: '一件一件来也没关系',
    ),
    '내일 또 만나': _SeedText(
      enTitle: 'See You Tomorrow',
      zhTitle: '明天见',
      enSubtitle: "A note to tomorrow's me",
      zhSubtitle: '留给明天的自己的话',
    ),
    '소소한 행복': _SeedText(
      enTitle: 'Little Joys',
      zhTitle: '小小的幸福',
      enSubtitle: 'What made me smile today',
      zhSubtitle: '今天让我微笑的事',
    ),
  };

  void _seed({int from = 0, AppLocale locale = AppLocale.ko}) {
    final seeds =
        <
          ({
            String title,
            String subtitle,
            String color,
            String cat,
            String badge,
            CatPose pose,
            BoardKind kind,
            List<String> lines,
          })
        >[
          (
            title: '오늘의 메모',
            subtitle: '',
            color: 'blossom',
            cat: 'ujoo',
            badge: 'heart',
            pose: CatPose.peekTop,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '기분 좋은 시작',
            subtitle: '오늘의 작은 목표',
            color: 'sky',
            cat: 'rocket',
            badge: 'spark',
            pose: CatPose.peekTop,
            kind: BoardKind.hearts,
            lines: <String>[],
          ),
          (
            title: '잠깐 쉬어가기',
            subtitle: '천천히 해도 괜찮아',
            color: 'sky',
            cat: 'cho',
            badge: 'moon',
            pose: CatPose.watermark,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '문득 떠오른 생각',
            subtitle: '',
            color: 'lilac',
            cat: 'nakksi',
            badge: 'bulb',
            pose: CatPose.peekLeft,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '오늘의 기분',
            subtitle: '',
            color: 'mint',
            cat: 'got',
            badge: 'smile',
            pose: CatPose.peekBottom,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '나에게 한마디',
            subtitle: '오늘도 잘했어',
            color: 'butter',
            cat: 'yuribyeong',
            badge: 'heart',
            pose: CatPose.peekBottom,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          // 두 번째 이야기.
          (
            title: '하나씩 해볼까',
            subtitle: '',
            color: 'apricot',
            cat: 'dalbit',
            badge: 'sprout',
            pose: CatPose.peekBottom,
            kind: BoardKind.checklist,
            lines: ['책 읽기', '산책하기', '메모 정리'],
          ),
          (
            title: '번뜩인 아이디어',
            subtitle: '',
            color: 'apricot',
            cat: 'usubu',
            badge: 'bulb',
            pose: CatPose.peekLeft,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '차분히 정리하기',
            subtitle: '',
            color: 'lilac',
            cat: 'byeolit',
            badge: 'spark',
            pose: CatPose.watermark,
            kind: BoardKind.checklist,
            lines: <String>[],
          ),
          (
            title: '괜찮아, 천천히',
            subtitle: '하나씩 해도 괜찮아',
            color: 'mint',
            cat: 'haemak',
            badge: 'none',
            pose: CatPose.peekTop,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '내일 또 만나',
            subtitle: '내일의 나에게 남기는 말',
            color: 'butter',
            cat: 'pungseon',
            badge: 'heart',
            pose: CatPose.peekTop,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          // 세 번째 묶음.
          (
            title: '소소한 행복',
            subtitle: '오늘 나를 웃게 한 것',
            color: 'blossom',
            cat: 'eunha',
            badge: 'paw',
            pose: CatPose.peekTop,
            kind: BoardKind.hearts,
            lines: <String>[],
          ),
        ];

    // 한 묶음을 같은 때에 놓는다. 마이크로초 차이로 '편집일 순'이
    // 뒤집히지 않게 하려는 것이다.
    final stamp = DateTime.now().toUtc();
    final start = from < _setStarts.length ? _setStarts[from] : seeds.length;
    for (var i = start; i < seeds.length; i++) {
      final s = seeds[i];
      // 카드 자체(색·고양이·자리 …)는 언어를 안 타지만, 적힌 글은 기기
      // 언어를 따른다. 옮긴 말은 그대로 저장한다 — 제목은 누구나 나중에
      // 고칠 수 있는 제 글이라, 나중에 언어를 바꿔도 되돌리지 않는다. 이관
      // 규칙은 한국어 제목만 살피므로, 처음부터 다른 말로 놓인 카드는
      // (기본값 그대로라도) 더 손대지 않는다 — 그 카드는 이미 최종 모습이다.
      final tx = _seedText[s.title];
      final board = Board.create(
        title: locale == AppLocale.ko || tx == null
            ? s.title
            : (locale == AppLocale.en ? tx.enTitle : tx.zhTitle),
        subtitle: locale == AppLocale.ko || tx == null
            ? s.subtitle
            : (locale == AppLocale.en ? tx.enSubtitle : tx.zhSubtitle),
        colorKey: s.color,
        catId: s.cat,
        badgeKey: s.badge,
        pose: s.pose,
        kind: s.kind,
        order: i,
      );
      board.updatedAt = stamp;
      if (pinnedSeeds.contains(s.title)) board.pinnedAt = stamp;
      _boards.add(board);
      final lines = locale == AppLocale.ko || tx == null
          ? s.lines
          : (locale == AppLocale.en ? tx.enLines : tx.zhLines);
      for (var k = 0; k < lines.length; k++) {
        _entries.add(Entry.create(boardId: board.id, text: lines[k], order: k));
      }
    }
  }

  /// 기본 카드의 글귀만 손본다. 직접 쓴 글은 건드리지 않는다.
  void _applyFixups() {
    // 고를 수 없게 된 표시를 쓰던 카드는 남아 있는 것으로 옮긴다.
    const movedBadges = {'flower': 'spark', 'clover': 'sprout'};
    final stamp = DateTime.now().toUtc();
    for (final board in _boards) {
      // 노을과 '마음 비우기'는 걷어냈다. 지운 흔적만 남기므로 예전
      // 되살릴 수 있다.
      if (board.title == '마음 비우기' && board.subtitle == '솔직한 마음을 적어요') {
        board.deletedAt ??= DateTime.now().toUtc();
      }
      if (board.catId == 'noeul') board.catId = 'mochi';
      if (board.subtitle == '작은 생각을 적어두기') board.subtitle = '';
      if (board.title == '잠깐 쉬어가기') board.subtitle = '천천히 해도 괜찮아';
      final moved = movedBadges[board.badgeKey];
      if (moved != null) board.badgeKey = moved;
      // 할 일 카드와 소소한 행복 카드는 처음부터 목록 맨 위에 붙박아 둔다.
      if (pinnedSeeds.contains(board.title)) board.pinnedAt ??= stamp;
      // 두 카드의 기본 고양이를 모찌로 바꿨다. 처음 받은 모습 그대로인
      // 카드만 옮기고, 직접 다른 아이를 골라 둔 카드는 그대로 둔다.
      if (board.title == '소소한 행복' && board.catId == 'nabi') {
        board.catId = 'mochi';
      }
      if (board.title == '기분 좋은 시작' &&
          board.catId == 'haneul' &&
          board.pose == CatPose.trio) {
        board.catId = 'mochi';
        board.pose = CatPose.peekTop;
      }
      // 기본 카드 열두 장의 고양이를 우주 고양이로 옮긴다. 위 두 규칙이 먼저
      // 돌아 '기분 좋은 시작'·'소소한 행복'은 이 시점에 이미 모찌라, 여기서는
      // 그 값을 기준으로 본다. 처음 받은 모습 그대로인 카드만 옮기고, 직접
      // 다른 아이를 골라 둔 카드는 그대로 둔다.
      const spaceDefaults = {
        '오늘의 메모': ('mochi', 'ujoo'),
        '하나씩 해볼까': ('dalgi', 'byeoltong'),
        '잠깐 쉬어가기': ('byeol', 'cho'),
        '문득 떠오른 생각': ('sol', 'nakksi'),
        '오늘의 기분': ('haneul', 'got'),
        '나에게 한마디': ('kongi', 'yuribyeong'),
        '기분 좋은 시작': ('mochi', 'rocket'),
        '번뜩인 아이디어': ('bori', 'byeolit'),
        '차분히 정리하기': ('mongi', 'wiseong'),
        '괜찮아, 천천히': ('dalrae', 'haemak'),
        '내일 또 만나': ('danchu', 'pungseon'),
        '소소한 행복': ('mochi', 'usubu'),
      };
      final swap = spaceDefaults[board.title];
      if (swap != null && board.catId == swap.$1) board.catId = swap.$2;
      // '소소한 행복'은 아래 자리에서 위에 걸터앉는 자리로 옮긴다. 기본 그대로인
      // 카드만 옮기고, 직접 다른 자리로 바꿔 둔 카드는 그대로 둔다.
      if (board.title == '소소한 행복' &&
          board.catId == 'usubu' &&
          board.pose == CatPose.peekBottom) {
        board.pose = CatPose.peekTop;
      }
      // '하나씩 해볼까'는 별똥에서 달빛으로 한 번 더 옮긴다. 자리(오른쪽
      // 아래)는 그대로다.
      if (board.title == '하나씩 해볼까' && board.catId == 'byeoltong') {
        board.catId = 'dalbit';
      }
      // 처음 만들었던 고양이 열한 마리와 '세 마리' 그림은 이제 어느 카드에도
      // 나오지 않는다. 위 규칙들이 기본 카드는 이미 우주 고양이로 옮겨 뒀으니,
      // 여기서는 그 규칙이 손대지 않은 나머지(사용자가 만든 카드, 직접 옛
      // 고양이로 골라 둔 카드)를 마저 옮긴다. 어느 아이를 받을지는 카드 번호로
      // 정해, 매번 다르되 같은 카드는 항상 같은 아이를 받는다.
      if (_retiredCats.contains(board.catId) || board.pose == CatPose.trio) {
        final i = board.id.hashCode.abs() % _spaceCatIds.length;
        board.catId = _spaceCatIds[i];
        if (board.pose == CatPose.trio) board.pose = CatPose.peekBottom;
      }
      // 기본으로 붙박아 두는 카드를 '소소한 행복'에서 '기분 좋은 시작'으로
      // 바꾼다. pinnedSeeds 를 고치는 것만으로는 이미 붙박아 둔 '소소한
      // 행복'을 떼지 못하므로(위 줄은 붙이기만 하고 떼지는 않는다) 여기서
      // 직접 뗀다.
      if (board.title == '소소한 행복') board.pinnedAt = null;
      // '차분히 정리하기'는 위성에서 별잇기로 한 번 더 옮긴다.
      if (board.title == '차분히 정리하기' && board.catId == 'wiseong') {
        board.catId = 'byeolit';
      }
      // '기분 좋은 시작'과 '하나씩 해볼까'의 차례를 맞바꾼다. 이 값은 화면
      // 어디서도 손으로 고칠 수 없어, 기본 그대로인지 따지지 않고 늘 맞바꾼다.
      if (board.title == '기분 좋은 시작') board.order = 1;
      if (board.title == '하나씩 해볼까') board.order = 6;
      // '번뜩인 아이디어'는 별잇기에서 우주복으로 한 번 더 옮긴다. 자리(왼쪽
      // 아래)는 그대로다.
      if (board.title == '번뜩인 아이디어' && board.catId == 'byeolit') {
        board.catId = 'usubu';
      }
      // '소소한 행복'은 우주복에서 은하로 한 번 더 옮긴다. 자리(위에
      // 걸터앉기)는 그대로다.
      if (board.title == '소소한 행복' && board.catId == 'usubu') {
        board.catId = 'eunha';
      }
    }
  }

  /// 처음 만들었던 고양이 열한 마리. [_applyFixups] 가 다른 아이로 옮긴다.
  static const _retiredCats = {
    'mochi',
    'dalgi',
    'byeol',
    'sol',
    'nabi',
    'kongi',
    'haneul',
    'bori',
    'mongi',
    'dalrae',
    'danchu',
  };

  /// 우주 고양이 열여덟 마리. [lib/widgets/original_artwork.dart] 의
  /// spaceCats 와 같은 목록이다 — 위젯을 들여오지 않으려고 여기 따로 적는다.
  static const _spaceCatIds = [
    'ujoo',
    'byeoltong',
    'dalbit',
    'eunha',
    'choco',
    'pyeonji',
    'cho',
    'byeol2',
    'usubu',
    'got',
    'rocket',
    'byeoljari',
    'nakksi',
    'yuribyeong',
    'wiseong',
    'pungseon',
    'haemak',
    'byeolit',
  ];

  /// 파일을 건드리지 않고 기본 카드만 채운다. 렌더링 검증용.
  @visibleForTesting
  void debugSeed() {
    _boards.clear();
    _entries.clear();
    _seed();
    _loaded = true;
    notifyListeners();
  }

  List<Attachment> attachmentsOf(String boardId) =>
      _attachments.where((a) => a.boardId == boardId && !a.deleted).toList();

  File attachmentFile(Attachment attachment) {
    final root = _file;
    if (root == null) throw StateError('저장소가 아직 준비되지 않았어요');
    return File('${root.parent.path}/attachments/${attachment.storageName}');
  }

  /// 이 글에서 마지막으로 커서가 있던 줄. 저장하지 않는다 — 첨부를 어느 줄
  /// 아래에 놓을지 정할 때만 쓴다.
  final Map<String, String> _lastFocusedEntry = {};

  void rememberFocusedEntry(String boardId, String entryId) =>
      _lastFocusedEntry[boardId] = entryId;

  /// 지금 첨부를 놓으면 들어갈 줄. 커서가 있던 줄이 아직 있으면 그 줄이고,
  /// 없으면 null 이라 글 맨 끝이다.
  String? entryForNewAttachment(String boardId) {
    final id = _lastFocusedEntry[boardId];
    if (id == null) return null;
    return entriesOf(boardId).any((e) => e.id == id) ? id : null;
  }

  /// 이 줄 바로 아래에 놓인 첨부. 첨부한 차례를 지킨다.
  List<Attachment> attachmentsAfter(String boardId, String entryId) =>
      attachmentsOf(boardId).where((a) => a.afterEntryId == entryId).toList();

  /// 놓인 줄이 없거나 지워져 글 맨 끝에 놓이는 첨부.
  List<Attachment> attachmentsAtEnd(String boardId) {
    final live = entriesOf(boardId).map((e) => e.id).toSet();
    return attachmentsOf(boardId)
        .where((a) => a.afterEntryId == null || !live.contains(a.afterEntryId))
        .toList();
  }

  /// 크기나 놓인 줄을 바꾼다.
  void setAttachmentLayout(
    Attachment attachment, {
    double? widthFraction,
    String? afterEntryId,
    bool moveToEnd = false,
  }) {
    if (widthFraction != null) {
      attachment.widthFraction = widthFraction.clamp(
        Attachment.minWidth,
        Attachment.maxWidth,
      );
    }
    if (afterEntryId != null || moveToEnd) {
      attachment.afterEntryId = afterEntryId;
    }
    _bump(attachment.boardId);
  }

  Future<void> addAttachment({
    required String boardId,
    required String name,
    required String kind,
    required Stream<List<int>> bytes,
    String? afterEntryId,
  }) async {
    if (_board(boardId)?.isAlive != true) return;
    final id = newId();
    final extension = name.contains('.') ? name.split('.').last : '';
    final suffix = RegExp(r'^[a-zA-Z0-9]{1,12}$').hasMatch(extension)
        ? '.${extension.toLowerCase()}'
        : '';
    final pending = Attachment(
      id: id,
      boardId: boardId,
      name: name,
      storageName: '$id$suffix',
      kind: kind,
      size: 0,
    );
    final target = attachmentFile(pending);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.part');
    try {
      final sink = temp.openWrite();
      try {
        await sink.addStream(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (_board(boardId)?.isAlive != true) {
        await temp.delete();
        return;
      }
      await temp.rename(target.path);
      final attachment = Attachment(
        id: id,
        boardId: boardId,
        name: name,
        storageName: pending.storageName,
        kind: kind,
        size: await target.length(),
        afterEntryId: afterEntryId,
      );
      _attachments.add(attachment);
      _bump(boardId);
      await flush();
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  void setAttachmentDeleted(Attachment attachment, bool deleted) {
    attachment.deleted = deleted;
    _bump(attachment.boardId);
  }

  // ------------------------------------------------------------------- 쓰기

  Entry addEntry(String boardId) {
    final existing = entriesOf(boardId);
    final entry = Entry.create(
      boardId: boardId,
      order: existing.isEmpty ? 0 : existing.last.order + 1,
    );
    _entries.add(entry);
    _bump(boardId);
    return entry;
  }

  /// 어떤 줄 바로 아래에 새 줄들을 끼운다.
  ///
  /// 엔터는 빈 줄 하나, 여러 줄을 붙여넣으면 그 줄 수만큼이다. 줄마다
  /// 따로 끼워야 붙여넣은 글이 한 줄에 뭉치지 않는다.
  List<Entry> insertEntriesAfter(String entryId, List<String> texts) {
    final at = _entry(entryId);
    if (at == null) throw StateError('없는 줄 아래에는 끼울 수 없어요');
    final room = texts.isEmpty ? 1 : texts.length;
    for (final e in entriesOf(at.boardId).where((e) => e.order > at.order)) {
      e.order += room;
      e.touch();
    }
    final made = <Entry>[];
    for (var i = 0; i < room; i++) {
      final entry = Entry.create(
        boardId: at.boardId,
        text: i < texts.length ? texts[i] : '',
        order: at.order + 1 + i,
      );
      _entries.add(entry);
      made.add(entry);
    }
    _bump(at.boardId);
    return made;
  }

  /// 빈 메모 한 장을 새로 놓는다. 색과 고양이는 부르는 쪽이 고른다 —
  /// 저장소가 화면의 색표를 알 이유는 없다.
  Board addBoard({
    required String colorKey,
    required String catId,
    String title = '새 메모',
  }) {
    final order =
        _boards.fold<int>(-1, (m, b) => b.order > m ? b.order : m) + 1;
    final board = Board.create(
      title: title,
      colorKey: colorKey,
      catId: catId,
      order: order,
    );
    _boards.add(board);
    _persist();
    return board;
  }

  void setEntryText(String entryId, String text) {
    final e = _entry(entryId);
    if (e == null || e.text == text) return;
    e.text = text;
    e.touch();
    _bump(e.boardId);
  }

  void toggleEntry(String entryId) {
    final e = _entry(entryId);
    if (e == null) return;
    e.checked = !e.checked;
    e.touch();
    _bump(e.boardId);
  }

  /// 소프트 삭제. 흔적을 남겨 두어야 스낵바에서 바로 되돌릴 수 있고,
  /// 나중에 다른 기기와 맞출 때 지웠다는 사실이 함께 전해진다.
  void deleteEntry(String entryId) {
    final e = _entry(entryId);
    if (e == null) return;
    // 이 줄 아래에 놓였던 사진은 위 줄 아래로 옮겨 제자리에 남긴다. 그대로 두면
    // 글 맨 끝으로 튀어 간다.
    final live = entriesOf(e.boardId);
    final at = live.indexWhere((x) => x.id == entryId);
    final above = at > 0 ? live[at - 1].id : null;
    for (final a in _attachments) {
      if (a.afterEntryId == entryId) a.afterEntryId = above;
    }
    e.deletedAt = DateTime.now().toUtc();
    e.touch();
    _bump(e.boardId);
  }

  void updateBoard(
    String boardId, {
    String? title,
    String? subtitle,
    String? colorKey,
    String? catId,
    String? badgeKey,
    CatPose? pose,
    BoardKind? kind,
  }) {
    final b = _board(boardId);
    if (b == null) return;
    if (title != null) b.title = title;
    if (subtitle != null) b.subtitle = subtitle;
    if (colorKey != null) b.colorKey = colorKey;
    if (catId != null) b.catId = catId;
    if (badgeKey != null) b.badgeKey = badgeKey;
    if (pose != null) b.pose = pose;
    if (kind != null) b.kind = kind;
    b.touch();
    _persist();
  }

  void setFont(String key) {
    if (!fontOptions.containsKey(key) || _fontKey == key) return;
    _fontKey = key;
    _persist();
  }

  void setBackground(String key) {
    if (_backgroundKey == key) return;
    _backgroundKey = key;
    _persist();
  }

  /// 스토어의 이 판을 알린 것으로 적어 둔다. 알린 때도 함께 적어, '나중에'를
  /// 누른 사람에게 며칠 뒤 다시 한 번 알릴 수 있게 한다.
  void markStoreVersionTold(String version) {
    _toldStoreVersion = version;
    _toldStoreAt = DateTime.now().toUtc();
    _persist();
  }

  void setSort(BoardSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    _persist();
  }

  /// 카드를 지운다. 줄과 마찬가지로 흔적만 남기므로 스낵바에서
  /// 되살릴 수 있고, 다른 기기와 맞출 때 지운 사실이 함께 전해진다.
  void deleteBoards(Iterable<String> boardIds) {
    final now = DateTime.now().toUtc();
    var hit = false;
    for (final id in boardIds) {
      final b = _board(id);
      if (b == null || !b.isAlive) continue;
      b.deletedAt = now;
      b.touch();
      hit = true;
    }
    if (hit) _persist();
  }

  /// 방금 지운 카드를 되살린다.
  void restoreBoards(Iterable<String> boardIds) {
    var hit = false;
    for (final id in boardIds) {
      final b = _board(id);
      if (b == null || b.isAlive) continue;
      b.deletedAt = null;
      b.touch();
      hit = true;
    }
    if (hit) _persist();
  }

  /// 목록 맨 위에 붙박거나 떼어 낸다.
  void togglePin(String boardId) {
    final b = _board(boardId);
    if (b == null) return;
    b.pinnedAt = b.isPinned ? null : DateTime.now().toUtc();
    // 붙박는 것은 내용을 고치는 일이 아니다. updatedAt 을 건드리면
    // '편집일 순'에서 엉뚱하게 앞으로 튀어나온다.
    _persist();
  }

  Board? _board(String id) => _boards.where((b) => b.id == id).firstOrNull;
  Entry? _entry(String id) => _entries.where((e) => e.id == id).firstOrNull;

  void _bump(String boardId) {
    _board(boardId)?.touch();
    _persist();
  }

  void _persist() {
    notifyListeners();
    _scheduleSave();
  }

  // ------------------------------------------------------------------- 저장

  /// 타자 한 글자마다 파일을 쓰지 않도록 묶어서 저장한다.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> _pendingSave = Future<void>.value();

  Future<void> flush() {
    final next = _pendingSave.then((_) => _flushNow());
    _pendingSave = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _flushNow() async {
    _saveTimer?.cancel();
    final f = _file;
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(toBundle()));
    // 쓰는 도중 앱이 죽어도 원본이 반쯤 덮이지 않도록 원자적으로 교체한다.
    await tmp.rename(f.path);
  }

  /// 설계 문서의 봉투 포맷. 저장 파일이 이 모양으로 쌓인다.
  Map<String, dynamic> toBundle() => {
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'deviceId': _deviceId,
    'counts': {'boards': _boards.length, 'entries': _entries.length},
    'settings': {
      'backgroundKey': _backgroundKey,
      'fontKey': _fontKey,
      'seedSets': _seededSets,
      'fixups': _fixups,
      'toldStoreVersion': _toldStoreVersion,
      'toldStoreAt': _toldStoreAt?.toIso8601String(),
      'sort': _sort.name,
    },
    'boards': _boards.map((b) => b.toJson()).toList(),
    'entries': _entries.map((e) => e.toJson()).toList(),
    'attachments': _attachments.map((a) => a.toJson()).toList(),
  };

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
