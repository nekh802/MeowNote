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
    'sol' => const Rect.fromLTRB(60, 748, 250, 916),
    'trio' => const Rect.fromLTRB(551, 785, 984, 916),
    'nabi' => const Rect.fromLTRB(820, 793, 984, 916),
    'kongi' => const Rect.fromLTRB(1262, 761, 1468, 915),
    'title' => const Rect.fromLTRB(493, 22, 1051, 142),
    // 두 번째 장.
    'haneul' => const Rect.fromLTRB(300, 396, 509, 538),
    'noeul' => const Rect.fromLTRB(812, 133, 1001, 282),
    'bori' => const Rect.fromLTRB(1040, 388, 1276, 538),
    'mongi' => const Rect.fromLTRB(274, 845, 509, 978),
    'dalrae' => const Rect.fromLTRB(722, 848, 971, 978),
    'danchu' => const Rect.fromLTRB(1302, 574, 1495, 733),
    _ => const Rect.fromLTRB(316, 126, 500, 244),
  };

  /// 오려 둔 그림 파일. 이름을 모르면 첫 고양이로 돌아간다.
  static String cutout(String art) =>
      'assets/cutouts/${cutouts.contains(art) ? art : 'mochi'}.png';

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
    'noeul',
    'bori',
    'mongi',
    'dalrae',
    'danchu',
  };

  @override
  Widget build(BuildContext context) {
    final rect = bounds(art);
    return ExcludeSemantics(
      child: Image.asset(
        cutout(art),
        width: width,
        height: width * rect.height / rect.width,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
