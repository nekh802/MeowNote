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
    'nabi' => const Rect.fromLTRB(830, 793, 984, 916),
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

/// Original handwriting, with light paper suppressed by an alpha color filter.
/// Custom titles remain editable text; only unchanged sample labels use this.
class OriginalLabel extends StatelessWidget {
  const OriginalLabel({super.key, required this.text, required this.height});
  final String text;
  final double height;

  static const regions = <String, Rect>{
    '오늘의 메모': Rect.fromLTRB(95, 188, 265, 235),
    '하나씩 해볼까': Rect.fromLTRB(574, 188, 797, 236),
    '잠깐 쉬어가기': Rect.fromLTRB(1059, 188, 1283, 237),
    '문득 떠오른 생각': Rect.fromLTRB(94, 575, 337, 625),
    '오늘의 기분': Rect.fromLTRB(575, 577, 736, 625),
    '나에게 한마디': Rect.fromLTRB(1058, 576, 1295, 625),
    '작은 생각을 적어두기': Rect.fromLTRB(102, 252, 314, 283),
    '천천히 해도 괜찮아': Rect.fromLTRB(1068, 252, 1269, 283),
    '오늘도 잘했어': Rect.fromLTRB(1066, 638, 1212, 669),
  };

  @override
  Widget build(BuildContext context) {
    final rect = regions[text]!;
    final scale = height / rect.height;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: SizedBox(
          width: rect.width * scale,
          height: height,
          child: ClipRect(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                -2.04,
                -2.04,
                -2.04,
                0,
                1020,
              ]),
              child: Stack(
                children: [
                  Positioned(
                    left: -rect.left * scale,
                    top: -rect.top * scale,
                    width: 1536 * scale,
                    height: 1024 * scale,
                    child: Image.asset(
                      OriginalArtwork.asset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
