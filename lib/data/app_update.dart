import 'dart:convert';
import 'dart:io';

/// 앱스토어에 더 새로운 판이 올라왔는지 묻는다.
///
/// 애플이 열어 둔 조회 창구를 그대로 쓴다. 따로 서버를 두지 않아도 되고,
/// 심사를 마친 판만 답으로 오므로 아직 올리지 않은 판을 잘못 알리는 일이
/// 없다. 대답이 없거나 아직 스토어에 없는 앱이면 조용히 지나간다 —
/// 인터넷이 없다고 메모장을 못 쓸 이유는 없다.
class StoreRelease {
  const StoreRelease({required this.version, required this.page});

  final String version;
  final Uri page;
}

class AppUpdate {
  /// 스토어에 올라온 판. 물어볼 수 없으면 null.
  static Future<StoreRelease?> lookUp(String bundleId) async {
    // 아이폰에만 앱스토어가 있다. 그 밖에서는 묻지 않는다.
    if (!Platform.isIOS) return null;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final url = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': bundleId,
      });
      final res = await client.getUrl(url).then((r) => r.close());
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final results = (jsonDecode(body) as Map<String, dynamic>)['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final version = first['version'] as String?;
      final page = first['trackViewUrl'] as String?;
      if (version == null || page == null) return null;
      return StoreRelease(version: version, page: Uri.parse(page));
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}

/// 1.2.0 과 1.10.0 처럼 마디마다 숫자로 견준다. 글자 순서로 견주면
/// 1.10 이 1.9 보다 앞서 버린다.
bool isNewerVersion(String store, String mine) {
  final a = _parts(store), b = _parts(mine);
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

List<int> _parts(String v) =>
    v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
