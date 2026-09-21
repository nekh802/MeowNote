import 'package:flutter/material.dart';

/// Displays the supplied PNG itself. No generated or redrawn artwork is used.
///
/// 그림마다 원본에서 외곽선 바깥만 투명하게 오려 둔 PNG 를 쓴다. 색은 원본
/// 픽셀 그대로이고 알파만 깎여 있어, 어떤 카드 색 위에 올려도 테두리 바깥에
/// 원본 종이 색이 남지 않는다. 오려내기는 `tool/cutout_artwork.py` 가 한다.
class OriginalArtwork extends StatelessWidget {
  const OriginalArtwork({super.key, required this.art, required this.width});

  final String art;
  final double width;
  static const asset = 'assets/malang1.png';

  /// 원본에서 그림이 놓인 자리. 오려 둔 PNG 도 같은 크기라 배치 좌표와
  /// 가로세로 비율을 여기서 그대로 얻는다.
  static Rect bounds(String art) => switch (art) {
    'mochi' => const Rect.fromLTRB(316, 126, 500, 244),
    'dalgi' => const Rect.fromLTRB(779, 407, 983, 532),
    'byeol' => const Rect.fromLTRB(1098, 362, 1460, 532),
    'sol' => const Rect.fromLTRB(48, 748, 250, 916),
    'trio' => const Rect.fromLTRB(551, 785, 984, 916),
    'nabi' => const Rect.fromLTRB(812, 793, 984, 916),
    'kongi' => const Rect.fromLTRB(1262, 761, 1468, 915),
    'title' => const Rect.fromLTRB(493, 22, 1051, 142),
    // 두 번째 장.
    'haneul' => const Rect.fromLTRB(300, 396, 509, 538),
    'bori' => const Rect.fromLTRB(1040, 388, 1276, 538),
    'mongi' => const Rect.fromLTRB(274, 845, 509, 978),
    'dalrae' => const Rect.fromLTRB(722, 848, 971, 978),
    'danchu' => const Rect.fromLTRB(1302, 574, 1495, 733),
    // 세 번째 장(남색 하늘의 우주 고양이). 원본이 아니라 오려 낸 그림의 크기를
    // 그대로 적는다 — 가로세로 비율만 쓰인다.
    'ujoo' => const Rect.fromLTRB(0, 0, 462, 414),
    'byeoltong' => const Rect.fromLTRB(0, 0, 468, 439),
    'dalbit' => const Rect.fromLTRB(0, 0, 460, 406),
    'eunha' => const Rect.fromLTRB(0, 0, 466, 407),
    'choco' => const Rect.fromLTRB(0, 0, 437, 433),
    'pyeonji' => const Rect.fromLTRB(0, 0, 501, 414),
    // 네 번째 장.
    'cho' => const Rect.fromLTRB(0, 0, 464, 450),
    'byeol2' => const Rect.fromLTRB(0, 0, 469, 432),
    'usubu' => const Rect.fromLTRB(0, 0, 443, 430),
    'got' => const Rect.fromLTRB(0, 0, 490, 415),
    'rocket' => const Rect.fromLTRB(0, 0, 466, 405),
    'byeoljari' => const Rect.fromLTRB(0, 0, 490, 374),
    // 다섯 번째 장.
    'nakksi' => const Rect.fromLTRB(0, 0, 473, 470),
    'yuribyeong' => const Rect.fromLTRB(0, 0, 432, 395),
    'wiseong' => const Rect.fromLTRB(0, 0, 500, 389),
    'pungseon' => const Rect.fromLTRB(0, 0, 415, 481),
    'haemak' => const Rect.fromLTRB(0, 0, 494, 382),
    'byeolit' => const Rect.fromLTRB(0, 0, 496, 393),
    _ => const Rect.fromLTRB(316, 126, 500, 244),
  };

  /// 남색 하늘에 그린 우주 고양이. 테두리를 외곽선 색으로 이미 칠해 두어 낮·밤
  /// 짝이 따로 없다.
  static const spaceCats = <String>{
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
  };

  /// 기존 고양이는 가슴 위만 그려 가로로 넓지만 우주 고양이는 온몸이라 통통하다.
  /// 같은 폭으로 놓으면 카드 아래 칸(글 자리)을 넘어 글자를 가린다. 그래서 높이가
  /// 기존 고양이와 같아지도록 폭을 줄인 값([_spaceFit])에, 그림이 작다는 말이 있어
  /// 키운 배수([spaceScale])를 곱한다.
  static const spaceScale = 1.5;

  static double footprint(String art) {
    if (!spaceCats.contains(art)) return 1;
    final r = bounds(art);
    // 기존 고양이의 높이/폭 비율은 0.62 안팎이다.
    final fit = (.62 / (r.height / r.width)).clamp(.5, 1.0);
    return fit * spaceScale;
  }

  /// 오려 둔 그림 파일. 이름을 모르면 첫 고양이로 돌아간다. [night] 이면
  /// 테두리를 외곽선 색으로 이어 칠한 짝을 쓴다 — 남색 하늘 위에서 원본
  /// 종이 색이 하얀 띠로 뜨지 않는다.
  static String cutout(String art, {bool night = false}) =>
      'assets/cutouts/${night && !spaceCats.contains(art) ? 'night/' : ''}'
      '${cutouts.contains(art) ? art : 'mochi'}.png';

  static const cutouts = <String>{
    'mochi',
    'dalgi',
    'byeol',
    'sol',
    'trio',
    'nabi',
    'kongi',
    'title',
    'haneul',
    'bori',
    'mongi',
    'dalrae',
    'danchu',
    ...spaceCats,
  };

  @override
  Widget build(BuildContext context) {
    final rect = bounds(art);
    final w = width * footprint(art);
    return ExcludeSemantics(
      child: Image.asset(
        cutout(art, night: NightArtwork.of(context)),
        width: w,
        height: w * rect.height / rect.width,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// 이 아래 그림들이 밤하늘 위에 놓이는지 알린다. 창(바텀시트)은 밝은 바탕이라
/// 이 밖에 있어 낮 그림을 그대로 쓴다.
class NightArtwork extends InheritedWidget {
  const NightArtwork({super.key, required this.on, required super.child});

  final bool on;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NightArtwork>()?.on ?? false;

  @override
  bool updateShouldNotify(NightArtwork oldWidget) => oldWidget.on != on;
}
