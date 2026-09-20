import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

/// 앱스토어에 더 새로운 판이 올라왔는지 묻는다.
///
/// 애플이 열어 둔 조회 창구를 그대로 쓴다. 따로 서버를 두지 않아도 되고,
/// 심사를 마친 판만 답으로 오므로 아직 올리지 않은 판을 잘못 알리는 일이
/// 없다. 대답이 없거나 아직 스토어에 없는 앱이면 조용히 지나간다 —
/// 인터넷이 없다고 메모장을 못 쓸 이유는 없다.
class StoreRelease {
  const StoreRelease({
    required this.version,
    required this.page,
    required this.fallbackPage,
    this.notes = '',
  });

  final String version;

  /// 앱스토어 앱을 곧바로 여는 주소.
  final Uri page;

  /// 앱스토어 앱이 열리지 않을 때 브라우저로 여는 주소.
  final Uri fallbackPage;

  /// 이번 판에서 바뀐 점. 없으면 빈 글.
  final String notes;
}

class AppUpdate {
  /// 스토어에 올라온 판. 물어볼 수 없으면 null.
  ///
  /// 조회 창구는 나라를 정하지 않으면 미국 스토어만 뒤진다. 한국에만 낸
  /// 앱은 그러면 언제나 빈 답이라, 기기의 나라와 한국·미국을 차례로 묻는다.
  static Future<StoreRelease?> lookUp(String bundleId) async {
    // 아이폰에만 앱스토어가 있다. 그 밖에서는 묻지 않는다.
    if (!Platform.isIOS) return null;
    for (final country in countries()) {
      final release = await _ask(bundleId, country);
      if (release != null) return release;
    }
    return null;
  }

  /// 물어볼 나라. 기기의 나라가 먼저고, 겹치는 나라는 한 번만 묻는다.
  static List<String> countries() {
    final own = PlatformDispatcher.instance.locale.countryCode?.toLowerCase();
    return {if (own != null && own.length == 2) own, 'kr', 'us'}.toList();
  }

  static Future<StoreRelease?> _ask(String bundleId, String country) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final url = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': bundleId,
        'country': country,
        // 새 판을 올린 직후에는 옛 답이 캐시에 남아 있을 수 있다.
        'nocache': '${DateTime.now().millisecondsSinceEpoch}',
      });
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return parseRelease(body);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// 조회 창구의 답에서 판 정보를 뽑는다. 앱이 없거나 모양이 다르면 null.
  static StoreRelease? parseRelease(String body) {
    try {
      final results = (jsonDecode(body) as Map<String, dynamic>)['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final version = first['version'] as String?;
      final view = first['trackViewUrl'] as String?;
      final id = first['trackId'];
      if (version == null || view == null) return null;
      final web = Uri.parse(view);
      return StoreRelease(
        version: version,
        // 브라우저를 거치지 않고 앱스토어 앱의 이 앱 화면으로 바로 간다.
        page: id == null
            ? web
            : Uri.parse('itms-apps://apps.apple.com/app/id$id'),
        fallbackPage: web,
        notes: (first['releaseNotes'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
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
