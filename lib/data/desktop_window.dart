import 'dart:io';

import 'package:flutter/services.dart';

/// 맥에서 쪽지 창을 옮긴다.
///
/// 제목줄을 감춘 창이라 끌 자리가 따로 없다. 창 맨 위 손잡이를 누르면
/// 여기를 거쳐 맥 쪽에서 창을 끌고 간다. 다른 기기에서는 아무 일도 하지
/// 않으므로, 부르는 쪽에서 기기를 가릴 필요가 없다.
class DesktopWindow {
  const DesktopWindow._();

  static const _channel = MethodChannel('malang/window');

  /// 이 기기에서 창을 끌어 옮길 수 있는지.
  static bool get canDrag => Platform.isMacOS;

  static Future<void> startDrag() async {
    if (!canDrag) return;
    try {
      await _channel.invokeMethod<void>('drag');
    } on PlatformException {
      // 창이 없는 판(테스트 등)에서는 그냥 둔다.
    } on MissingPluginException {
      // 채널이 없는 기기 — 끌 수 없을 뿐이다.
    }
  }
}
