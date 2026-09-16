import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'memo_store.dart';

/// 백업 한 벌을 가리키는 손잡이.
class BackupRef {
  const BackupRef({
    required this.remoteId,
    required this.createdAt,
    required this.bytes,
    required this.contentHash,
  });

  final String remoteId;
  final DateTime createdAt;
  final int bytes;
  final String contentHash;
}

/// 백업이 어디에 저장되는지를 감춘다.
///
/// 지금 구현체는 로컬 파일 하나뿐이지만, Google Drive 를 붙일 때
/// 이 인터페이스만 새로 구현하면 백업 로직은 손대지 않아도 된다.
/// 플랫폼마다 다른 인증 방식(모바일은 google_sign_in, 윈도우는 루프백
/// OAuth)도 이 뒤에 숨는다.
abstract class BackupTarget {
  String get id;

  Future<BackupRef> upload(String json);
  Future<List<BackupRef>> list(); // 최신순
  Future<String> download(BackupRef ref);
  Future<void> delete(BackupRef ref);
}

/// 앱 지원 폴더 안 `backups/` 에 세대별로 쌓는다.
class LocalBackupTarget implements BackupTarget {
  @override
  String get id => 'local';

  /// 최근 몇 개를 남길지. 한 파일을 계속 덮어쓰면 망가진 데이터가
  /// 멀쩡한 백업까지 밀어내므로 세대를 유지한다.
  static const keep = 7;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/backups');
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<BackupRef> upload(String json) async {
    final dir = await _dir();
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/memo-$stamp.json');
    await file.writeAsString(json);
    await _rotate();
    return BackupRef(
      remoteId: file.path,
      createdAt: DateTime.now().toUtc(),
      bytes: utf8.encode(json).length,
      contentHash: hashOf(json),
    );
  }

  @override
  Future<List<BackupRef>> list() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // 파일명이 곧 시간순

    return files.map((f) {
      final stat = f.statSync();
      return BackupRef(
        remoteId: f.path,
        createdAt: stat.modified.toUtc(),
        bytes: stat.size,
        contentHash: '',
      );
    }).toList();
  }

  @override
  Future<String> download(BackupRef ref) => File(ref.remoteId).readAsString();

  @override
  Future<void> delete(BackupRef ref) async {
    final f = File(ref.remoteId);
    if (await f.exists()) await f.delete();
  }

  Future<void> _rotate() async {
    final refs = await list();
    for (final old in refs.skip(keep)) {
      await delete(old);
    }
  }

  /// 내용이 그대로면 굳이 새 세대를 만들지 않는다.
  static String hashOf(String json) =>
      sha256.convert(utf8.encode(json)).toString();
}

/// 백업을 언제 뜰지 결정하고, 실제 저장은 [BackupTarget] 에 맡긴다.
class BackupService {
  BackupService({BackupTarget? target})
    : target = target ?? LocalBackupTarget();

  final BackupTarget target;
  String? _lastHash;

  /// 앱이 백그라운드로 갈 때 호출. 바뀐 게 없으면 아무 일도 하지 않는다.
  Future<BackupRef?> backupIfChanged() async {
    final store = MemoStore.instance;
    final json = jsonEncode(store.toBundle());
    final hash = LocalBackupTarget.hashOf(json);
    if (hash == _lastHash) return null;

    final ref = await target.upload(json);
    _lastHash = hash;
    store.markBackedUp(ref.createdAt);
    return ref;
  }

  /// 사용자가 직접 눌렀을 때는 변경 여부와 무관하게 뜬다.
  Future<BackupRef> backupNow() async {
    final store = MemoStore.instance;
    final json = jsonEncode(store.toBundle());
    final ref = await target.upload(json);
    _lastHash = LocalBackupTarget.hashOf(json);
    store.markBackedUp(ref.createdAt);
    return ref;
  }

  /// 파일로 꺼내기 — OS 공유 시트에 넘기면 사용자가 iCloud Drive,
  /// Google Drive, 메일 어디로든 직접 보낼 수 있다. 클라우드 API 를
  /// 붙이기 전에도 "내 데이터를 언제든 빼갈 수 있다"가 성립한다.
  Future<void> exportToShareSheet() async {
    final store = MemoStore.instance;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/MalangCat-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(store.toBundle()),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Malang Cat 백업 ($stamp)',
      ),
    );
  }
}
