import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/memo.dart';
import '../theme/palette.dart';
import 'memo_store.dart';

/// 홈 화면 위젯에 보낼 간추린 메모.
///
/// 위젯은 앱과 따로 도는 작은 프로그램이라 저장 파일을 그대로 읽지 못한다.
/// 그래서 보여 줄 만큼만 추려 공유 서랍에 적어 둔다. 색까지 함께 보내
/// 카드와 위젯의 색이 어긋나지 않는다.
class WidgetFeed {
  WidgetFeed._();

  static const _channel = MethodChannel('malang/widget');

  /// 위젯에 올릴 카드 수와 카드마다 보낼 줄 수. 넉넉히 보내고 고르는 건
  /// 위젯 쪽에서 한다.
  static const _cards = 4;
  static const _lines = 8;

  static String _hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  /// 제목 옆 표시를 위젯이 아는 이름으로 옮긴다. 위젯은 앱의 아이콘
  /// 꾸러미를 쓰지 못하므로 시스템 그림 이름으로 건넨다.
  static const _badgeGlyph = {
    'heart': 'heart.fill',
    'sprout': 'leaf.fill',
    'moon': 'moon.fill',
    'bulb': 'lightbulb.fill',
    'smile': 'face.smiling',
    'star': 'star.fill',
    'paw': 'pawprint.fill',
    'cloud': 'cloud.fill',
    'spark': 'sparkles',
  };

  static Map<String, dynamic> bundle(MemoStore store) {
    final notes = <Map<String, dynamic>>[];
    for (final board in store.boards.take(_cards)) {
      final palette = CardPalette.byKey(board.colorKey);
      final badge = CardBadge.byKey(board.badgeKey);
      final entries = store.entriesOf(board.id);
      notes.add({
        'title': board.title,
        'badge': _badgeGlyph[board.badgeKey] ?? '',
        'badgeColor': _hex(badge.color),
        'bg': _hex(palette.bg),
        'ink': _hex(palette.ink),
        'tint': _hex(palette.tint),
        'line': _hex(palette.line),
        // 세 마리를 앉힌 카드는 그 그림을 그대로 보낸다.
        'cat': board.pose == CatPose.trio ? 'trio' : board.catId,
        'kind': board.kind.name,
        'lines': [
          for (final entry in entries.take(_lines))
            {'text': entry.text, 'checked': entry.checked},
        ],
        'done': entries.where((e) => e.checked).length,
        'total': entries.length,
      });
    }
    return {'notes': notes};
  }

  /// 위젯을 새로 그리게 한다. 아이폰이 아니면 조용히 넘어간다.
  static Future<void> publish(MemoStore store) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('publish', jsonEncode(bundle(store)));
    } on PlatformException catch (e) {
      debugPrint('위젯 갱신 실패: ${e.message}');
    } on MissingPluginException {
      // 위젯을 붙이기 전 빌드에서는 통로가 없다.
    }
  }
}
