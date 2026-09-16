import 'package:flutter/material.dart';
import 'original_artwork.dart';

/// 눈 모양.
enum EyeStyle { happy, open, wide, sleepy, wink }

/// 입 모양.
enum MouthStyle { w, openSmile }

/// 머리 무늬.
enum MarkStyle { none, earPatch, sidePatch, greyCap }

/// 곁들이는 작은 장식.
enum CatCharm { none, sparkle, heart, question, zzz }

/// 저장된 고양이 선택 ID와 표시 이름. 실제 그림은 원본 PNG를 사용한다.
class CatSpec {
  const CatSpec({
    required this.id,
    required this.name,
    required this.body,
    required this.mark,
    required this.markColor,
    required this.eyes,
    this.mouth = MouthStyle.w,
    this.charm = CatCharm.none,
  });

  final String id;
  final String name;
  final Color body;
  final MarkStyle mark;
  final Color markColor;
  final EyeStyle eyes;
  final MouthStyle mouth;
  final CatCharm charm;

  static const _cream = Color(0xFFFFFAF4);
  static const _ginger = Color(0xFFF0C48E);
  static const _grey = Color(0xFFBDB6B0);

  /// 웃으며 입을 벌린 아이 — 첫 카드에서 위로 넘겨다본다.
  static const mochi = CatSpec(
    id: 'mochi',
    name: '모찌',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.sparkle,
  );

  /// 신난 아이.
  static const dalgi = CatSpec(
    id: 'dalgi',
    name: '달기',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.heart,
  );

  /// 자는 아이 — 카드 안에 옅게 깔린다.
  static const byeol = CatSpec(
    id: 'byeol',
    name: '별이',
    body: _cream,
    mark: MarkStyle.none,
    markColor: _grey,
    eyes: EyeStyle.sleepy,
    mouth: MouthStyle.w,
    charm: CatCharm.zzz,
  );

  /// 갸웃하는 아이.
  static const sol = CatSpec(
    id: 'sol',
    name: '솔이',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: _ginger,
    eyes: EyeStyle.wide,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.question,
  );

  /// 회색 얼룩 아이.
  static const nabi = CatSpec(
    id: 'nabi',
    name: '나비',
    body: _cream,
    mark: MarkStyle.greyCap,
    markColor: _grey,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.w,
  );

  /// 눈을 꼭 감고 웃는 아이.
  static const kongi = CatSpec(
    id: 'kongi',
    name: '콩이',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.w,
    charm: CatCharm.heart,
  );

  // 두 번째 장(두 번째 이야기)의 여섯 마리.

  /// 하늘색 귀 — 첫 카드 아래에서 올라온다.
  static const haneul = CatSpec(
    id: 'haneul',
    name: '하늘',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: Color(0xFFBBD7F2),
    eyes: EyeStyle.happy,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.sparkle,
  );

  /// 눈을 꼭 감은 노랑둥이.
  static const noeul = CatSpec(
    id: 'noeul',
    name: '노을',
    body: _cream,
    mark: MarkStyle.greyCap,
    markColor: _ginger,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.w,
    charm: CatCharm.question,
  );

  /// 별을 달고 놀란 아이.
  static const bori = CatSpec(
    id: 'bori',
    name: '보리',
    body: _ginger,
    mark: MarkStyle.none,
    markColor: _ginger,
    eyes: EyeStyle.wide,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.sparkle,
  );

  /// 한쪽 귀가 회색인 아이 — 꾸벅꾸벅.
  static const mongi = CatSpec(
    id: 'mongi',
    name: '몽이',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: _grey,
    eyes: EyeStyle.open,
    mouth: MouthStyle.w,
    charm: CatCharm.zzz,
  );

  /// 앞발을 모으고 윙크하는 아이.
  static const dalrae = CatSpec(
    id: 'dalrae',
    name: '달래',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.wink,
    mouth: MouthStyle.w,
    charm: CatCharm.sparkle,
  );

  /// 손을 흔드는 아이 — 내일 또 만나.
  static const danchu = CatSpec(
    id: 'danchu',
    name: '단추',
    body: _ginger,
    mark: MarkStyle.greyCap,
    markColor: _ginger,
    eyes: EyeStyle.open,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.heart,
  );

  static const all = <CatSpec>[
    mochi,
    dalgi,
    byeol,
    sol,
    nabi,
    kongi,
    haneul,
    noeul,
    bori,
    mongi,
    dalrae,
    danchu,
  ];

  static CatSpec byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => mochi);
}

/// Original illustration selected from the supplied malang1.png.
class CatFace extends StatelessWidget {
  const CatFace({
    super.key,
    required this.spec,
    required this.width,
    this.opacity = 1,
    this.tint,
  });
  final CatSpec spec;
  final double width;
  final double opacity;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final art = OriginalArtwork(art: spec.id, width: width);
    return opacity >= 1 ? art : Opacity(opacity: opacity, child: art);
  }
}
