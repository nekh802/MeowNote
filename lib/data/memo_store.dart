import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/memo.dart';

/// 로컬 우선 저장소.
///
/// 원본은 항상 이 기기의 파일이고, 서버는 나중에 붙을 중계소다. 그래서
/// 화면은 네트워크를 기다리지 않고, 비행기 모드에서도 전부 동작한다.
/// 모든 레코드가 [Board.updatedAt] / [Board.deletedAt] 을 들고 있어서
/// 나중에 델타 동기화와 백업 복원을 그대로 얹을 수 있다.
class MemoStore extends ChangeNotifier {
  MemoStore._();

  static final MemoStore instance = MemoStore._();

  static const schemaVersion = 1;
  static const appVersion = '1.5.2';

  final List<Board> _boards = [];
  final List<Entry> _entries = [];

  String _backgroundKey = 'paper';

  /// 이 기기에 이미 들어온 기본 카드 묶음의 수. 예전 파일에는 없으므로
  /// 첫 묶음만 받은 것으로 본다.
  int _seededSets = seedSets;
  int _fixups = fixups;
  String _deviceId = '';
  DateTime? _lastBackupAt;

  /// 스토어에 올라온 판 가운데 이미 한 번 알린 것. 같은 판을 켤 때마다
  /// 다시 묻지 않으려고 적어 둔다.
  String _toldStoreVersion = '';

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
  String get deviceId => _deviceId;
  DateTime? get lastBackupAt => _lastBackupAt;
  String get toldStoreVersion => _toldStoreVersion;
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
        _seed();
      }
      // 쓰던 기기에도 새로 그린 카드 묶음을 한 번만 얹는다. 적어 둔
      // 메모는 건드리지 않고 뒤에 붙인다.
      if (_seededSets < seedSets) {
        _seed(from: _seededSets);
        _seededSets = seedSets;
      }
      if (_fixups < fixups) {
        _applyFixups();
        _fixups = fixups;
      }
    } else {
      _seed();
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
    final settings = (j['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    _backgroundKey = (settings['backgroundKey'] ?? 'paper') as String;
    _seededSets = (settings['seedSets'] ?? 1) as int;
    _fixups = (settings['fixups'] ?? 0) as int;
    _toldStoreVersion = (settings['toldStoreVersion'] ?? '') as String;
    _sort = BoardSort.values.firstWhere(
      (s) => s.name == settings['sort'],
      orElse: () => BoardSort.edited,
    );
    _deviceId = (j['deviceId'] ?? '') as String;
    final backup = settings['lastBackupAt'];
    _lastBackupAt = backup == null ? null : DateTime.tryParse(backup as String);
  }

  /// 지금까지 넣어 둔 기본 카드 묶음의 수. 이미 쓰던 기기에도 새로 추가된
  /// 묶음이 한 번은 들어오도록 [load] 에서 이 값을 비교한다.
  static const seedSets = 2;

  /// 이미 만들어 둔 카드의 글귀를 손본 횟수. 새 값을 올리면 쓰던 기기에서도
  /// [_applyFixups] 가 한 번 돈다.
  static const fixups = 3;

  /// 묶음마다 어디서 시작하는지. 카드를 걷어내면 묶음 크기가 달라지므로
  /// 6의 배수로 셈하지 않고 자리를 그대로 적어 둔다.
  static const _setStarts = [0, 6];

  /// 첫 실행에 놓이는 열두 장. 컨셉아트 두 장의 구성 그대로다.
  void _seed({int from = 0}) {
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
            cat: 'mochi',
            badge: 'heart',
            pose: CatPose.peekTop,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '하나씩 해볼까',
            subtitle: '',
            color: 'apricot',
            cat: 'dalgi',
            badge: 'sprout',
            pose: CatPose.peekBottom,
            kind: BoardKind.checklist,
            lines: ['책 읽기', '산책하기', '메모 정리'],
          ),
          (
            title: '잠깐 쉬어가기',
            subtitle: '천천히 해도 괜찮아',
            color: 'sky',
            cat: 'byeol',
            badge: 'moon',
            pose: CatPose.watermark,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '문득 떠오른 생각',
            subtitle: '',
            color: 'lilac',
            cat: 'sol',
            badge: 'bulb',
            pose: CatPose.peekLeft,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '오늘의 기분',
            subtitle: '',
            color: 'mint',
            cat: 'nabi',
            badge: 'smile',
            pose: CatPose.trio,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '나에게 한마디',
            subtitle: '오늘도 잘했어',
            color: 'butter',
            cat: 'kongi',
            badge: 'heart',
            pose: CatPose.peekBottom,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          // 두 번째 이야기.
          (
            title: '기분 좋은 시작',
            subtitle: '오늘의 작은 목표',
            color: 'sky',
            cat: 'haneul',
            badge: 'spark',
            pose: CatPose.peekBottom,
            kind: BoardKind.hearts,
            lines: <String>[],
          ),
          (
            title: '번뜩인 아이디어',
            subtitle: '',
            color: 'apricot',
            cat: 'bori',
            badge: 'bulb',
            pose: CatPose.peekLeft,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '차분히 정리하기',
            subtitle: '',
            color: 'lilac',
            cat: 'mongi',
            badge: 'spark',
            pose: CatPose.peekBottom,
            kind: BoardKind.checklist,
            lines: <String>[],
          ),
          (
            title: '괜찮아, 천천히',
            subtitle: '하나씩 해도 괜찮아',
            color: 'mint',
            cat: 'dalrae',
            badge: 'sprout',
            pose: CatPose.peekBottom,
            kind: BoardKind.note,
            lines: <String>[],
          ),
          (
            title: '내일 또 만나',
            subtitle: '내일의 나에게 남기는 말',
            color: 'butter',
            cat: 'danchu',
            badge: 'heart',
            pose: CatPose.peekTop,
            kind: BoardKind.note,
            lines: <String>[],
          ),
        ];

    // 한 묶음을 같은 때에 놓는다. 마이크로초 차이로 '편집일 순'이
    // 뒤집히지 않게 하려는 것이다.
    final stamp = DateTime.now().toUtc();
    final start = from < _setStarts.length ? _setStarts[from] : seeds.length;
    for (var i = start; i < seeds.length; i++) {
      final s = seeds[i];
      final board = Board.create(
        title: s.title,
        subtitle: s.subtitle,
        colorKey: s.color,
        catId: s.cat,
        badgeKey: s.badge,
        pose: s.pose,
        kind: s.kind,
        order: i,
      );
      board.updatedAt = stamp;
      _boards.add(board);
      for (var k = 0; k < s.lines.length; k++) {
        _entries.add(
          Entry.create(boardId: board.id, text: s.lines[k], order: k),
        );
      }
    }
  }

  /// 기본 카드의 글귀만 손본다. 직접 쓴 글은 건드리지 않는다.
  void _applyFixups() {
    // 고를 수 없게 된 표시를 쓰던 카드는 남아 있는 것으로 옮긴다.
    const movedBadges = {'flower': 'spark', 'clover': 'sprout'};
    for (final board in _boards) {
      // 노을과 '마음 비우기'는 걷어냈다. 지운 흔적만 남기므로 예전
      // 백업에서 되살릴 수 있다.
      if (board.title == '마음 비우기' && board.subtitle == '솔직한 마음을 적어요') {
        board.deletedAt ??= DateTime.now().toUtc();
      }
      if (board.catId == 'noeul') board.catId = 'mochi';
      if (board.subtitle == '작은 생각을 적어두기') board.subtitle = '';
      if (board.title == '잠깐 쉬어가기') board.subtitle = '천천히 해도 괜찮아';
      final moved = movedBadges[board.badgeKey];
      if (moved != null) board.badgeKey = moved;
    }
  }

  /// 파일을 건드리지 않고 기본 카드만 채운다. 렌더링 검증용.
  @visibleForTesting
  void debugSeed() {
    _boards.clear();
    _entries.clear();
    _seed();
    _loaded = true;
    notifyListeners();
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

  /// 어떤 줄 바로 아래에 빈 줄을 끼운다. 줄 끝에서 엔터를 누르면
  /// 맨 아래가 아니라 그 자리 다음에 새 줄이 와야 한다.
  Entry insertEntryAfter(String entryId) {
    final at = _entry(entryId);
    if (at == null) throw StateError('없는 줄 아래에는 끼울 수 없어요');
    final after = entriesOf(at.boardId).where((e) => e.order > at.order);
    for (final e in after) {
      e.order += 1;
      e.touch();
    }
    final entry = Entry.create(boardId: at.boardId, order: at.order + 1);
    _entries.add(entry);
    _bump(at.boardId);
    return entry;
  }

  /// 빈 메모 한 장을 새로 놓는다. 색과 고양이는 부르는 쪽이 고른다 —
  /// 저장소가 화면의 색표를 알 이유는 없다.
  Board addBoard({required String colorKey, required String catId}) {
    final order =
        _boards.fold<int>(-1, (m, b) => b.order > m ? b.order : m) + 1;
    final board = Board.create(
      title: '새 메모',
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

  /// 소프트 삭제. 물리 삭제를 하면 예전 백업을 복원할 때 지운 줄이
  /// 되살아나므로, 지운 흔적을 남겨 둔다.
  void deleteEntry(String entryId) {
    final e = _entry(entryId);
    if (e == null) return;
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

  void setBackground(String key) {
    if (_backgroundKey == key) return;
    _backgroundKey = key;
    _persist();
  }

  /// 스토어의 이 판을 한 번 알린 것으로 적어 둔다.
  void markStoreVersionTold(String version) {
    if (_toldStoreVersion == version) return;
    _toldStoreVersion = version;
    _persist();
  }

  void setSort(BoardSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    _persist();
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

  void markBackedUp(DateTime at) {
    _lastBackupAt = at;
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

  // ---------------------------------------------------------------- 저장/백업

  /// 타자 한 글자마다 파일을 쓰지 않도록 묶어서 저장한다.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    final f = _file;
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(toBundle()));
    // 쓰는 도중 앱이 죽어도 원본이 반쯤 덮이지 않도록 원자적으로 교체한다.
    await tmp.rename(f.path);
  }

  /// 설계 문서의 백업 봉투 포맷. 저장 파일과 백업 파일이 같은 모양이라
  /// 복원 코드를 한 벌만 유지하면 된다.
  Map<String, dynamic> toBundle() => {
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'deviceId': _deviceId,
    'counts': {'boards': _boards.length, 'entries': _entries.length},
    'settings': {
      'backgroundKey': _backgroundKey,
      'seedSets': _seededSets,
      'fixups': _fixups,
      'toldStoreVersion': _toldStoreVersion,
      'sort': _sort.name,
      'lastBackupAt': _lastBackupAt?.toIso8601String(),
    },
    'boards': _boards.map((b) => b.toJson()).toList(),
    'entries': _entries.map((e) => e.toJson()).toList(),
  };

  /// 복원 — 병합 모드.
  ///
  /// 규칙은 넷뿐이다.
  ///   1. 양쪽에 같은 id → updatedAt 이 큰 쪽이 이긴다
  ///   2. 백업에만 있음 → 넣는다
  ///   3. 로컬에만 있음 → 그대로 둔다 (복원은 절대 삭제하지 않는다)
  ///   4. 알 수 없는 schemaVersion → 건드리지 않고 거절한다
  RestoreReport restoreMerge(Map<String, dynamic> bundle) {
    final version = (bundle['schemaVersion'] ?? 0) as int;
    if (version > schemaVersion) {
      throw const FormatException('더 새로운 버전의 백업이라 복원할 수 없어요.');
    }

    var added = 0, updated = 0, skipped = 0;

    void mergeInto<T>({
      required List<T> target,
      required List raw,
      required T Function(Map<String, dynamic>) parse,
      required String Function(T) idOf,
      required DateTime Function(T) updatedOf,
    }) {
      final byId = {for (final item in target) idOf(item): item};
      for (final r in raw) {
        final incoming = parse(r as Map<String, dynamic>);
        final existing = byId[idOf(incoming)];
        if (existing == null) {
          target.add(incoming);
          added++;
        } else if (updatedOf(incoming).isAfter(updatedOf(existing))) {
          target[target.indexOf(existing)] = incoming;
          updated++;
        } else {
          skipped++;
        }
      }
    }

    mergeInto<Board>(
      target: _boards,
      raw: bundle['boards'] as List? ?? [],
      parse: Board.fromJson,
      idOf: (b) => b.id,
      updatedOf: (b) => b.updatedAt,
    );
    mergeInto<Entry>(
      target: _entries,
      raw: bundle['entries'] as List? ?? [],
      parse: Entry.fromJson,
      idOf: (e) => e.id,
      updatedOf: (e) => e.updatedAt,
    );

    _persist();
    return RestoreReport(added: added, updated: updated, skipped: skipped);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

class RestoreReport {
  const RestoreReport({
    required this.added,
    required this.updated,
    required this.skipped,
  });

  final int added;
  final int updated;
  final int skipped;

  @override
  String toString() => '새로 $added개 · 갱신 $updated개 · 그대로 $skipped개';
}
