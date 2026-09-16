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
  static const appVersion = '1.0.0';

  final List<Board> _boards = [];
  final List<Entry> _entries = [];

  String _backgroundKey = 'paper';
  String _deviceId = '';
  DateTime? _lastBackupAt;

  File? _file;
  Timer? _saveTimer;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  String get backgroundKey => _backgroundKey;
  String get deviceId => _deviceId;
  DateTime? get lastBackupAt => _lastBackupAt;

  /// 살아 있는 카드만 순서대로.
  List<Board> get boards =>
      _boards.where((b) => b.isAlive).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

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
        (j['boards'] as List? ?? [])
            .map((e) => Board.fromJson(e as Map<String, dynamic>)),
      );
    _entries
      ..clear()
      ..addAll(
        (j['entries'] as List? ?? [])
            .map((e) => Entry.fromJson(e as Map<String, dynamic>)),
      );
    final settings = (j['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    _backgroundKey = (settings['backgroundKey'] ?? 'paper') as String;
    _deviceId = (j['deviceId'] ?? '') as String;
    final backup = settings['lastBackupAt'];
    _lastBackupAt = backup == null ? null : DateTime.tryParse(backup as String);
  }

  /// 첫 실행에 놓이는 여섯 장. 컨셉아트의 구성 그대로다.
  void _seed() {
    final seeds = <({
      String title,
      String subtitle,
      String color,
      String cat,
      String badge,
      CatPose pose,
      BoardKind kind,
      List<String> lines,
    })>[
      (
        title: '오늘의 메모',
        subtitle: '작은 생각을 적어두기',
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
    ];

    for (var i = 0; i < seeds.length; i++) {
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
      _boards.add(board);
      for (var k = 0; k < s.lines.length; k++) {
        _entries.add(Entry.create(boardId: board.id, text: s.lines[k], order: k));
      }
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
