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

  // 남색 하늘의 우주 고양이 여섯 마리. 몸 색과 무늬는 이 아이들을 가르는
  // 표시일 뿐이고, 실제 그림은 오려 둔 PNG 가 그린다.

  /// 유에프오를 타고 별을 보는 검은 아이.
  static const ujoo = CatSpec(
    id: 'ujoo',
    name: '우주',
    body: Color(0xFF3B3540),
    mark: MarkStyle.none,
    markColor: _grey,
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 별 그물로 별똥별을 잡는 주황 줄무늬.
  static const byeoltong = CatSpec(
    id: 'byeoltong',
    name: '별똥',
    body: _ginger,
    mark: MarkStyle.sidePatch,
    markColor: _ginger,
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  /// 달 위에서 망원경을 들여다보는 삼색.
  static const dalbit = CatSpec(
    id: 'dalbit',
    name: '달빛',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  /// 망토를 두르고 별꽃에 물을 주는 회색 줄무늬.
  static const eunha = CatSpec(
    id: 'eunha',
    name: '은하',
    body: _grey,
    mark: MarkStyle.greyCap,
    markColor: _grey,
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 별 수첩에 무언가를 적는 샴.
  static const choco = CatSpec(
    id: 'choco',
    name: '초코',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: Color(0xFF6B4F45),
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 별 우체통에 편지를 넣는 턱시도.
  static const pyeonji = CatSpec(
    id: 'pyeonji',
    name: '편지',
    body: Color(0xFF3B3540),
    mark: MarkStyle.none,
    markColor: _cream,
    eyes: EyeStyle.wink,
    charm: CatCharm.heart,
  );

  // 네 번째 장의 우주 고양이 여섯 마리.

  /// 초승달에 누워 눈을 감은 보라 무늬.
  static const cho = CatSpec(
    id: 'cho',
    name: '초승',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: Color(0xFFC9BBEE),
    eyes: EyeStyle.sleepy,
    charm: CatCharm.zzz,
  );

  /// 커다란 별을 끌어안은 삼색.
  static const byeol2 = CatSpec(
    id: 'byeol2',
    name: '별빛',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 우주복을 입고 둥둥 떠 다니는 삼색.
  static const usubu = CatSpec(
    id: 'usubu',
    name: '우주복',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.happy,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.sparkle,
  );

  /// 고리 행성에 매달린 두 마리.
  static const got = CatSpec(
    id: 'got',
    name: '고리',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: Color(0xFFC9BBEE),
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  /// 로켓을 타고 날아가는 삼색.
  static const rocket = CatSpec(
    id: 'rocket',
    name: '로켓',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.wink,
    mouth: MouthStyle.openSmile,
    charm: CatCharm.sparkle,
  );

  /// 별자리 아래 나란히 앉은 세 마리.
  static const byeoljari = CatSpec(
    id: 'byeoljari',
    name: '별자리',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: _grey,
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  // 다섯 번째 장의 우주 고양이 여섯 마리.

  /// 파란 행성에 앉아 별을 낚는, 잠옷 모자를 쓴 흰 아이.
  static const nakksi = CatSpec(
    id: 'nakksi',
    name: '낚시',
    body: _cream,
    mark: MarkStyle.none,
    markColor: Color(0xFFC9BBEE),
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 별을 가득 담은 유리병을 안은 주황 줄무늬.
  static const yuribyeong = CatSpec(
    id: 'yuribyeong',
    name: '별병',
    body: _ginger,
    mark: MarkStyle.sidePatch,
    markColor: _ginger,
    eyes: EyeStyle.open,
    charm: CatCharm.sparkle,
  );

  /// 인공위성에 올라탄 턱시도.
  static const wiseong = CatSpec(
    id: 'wiseong',
    name: '위성',
    body: Color(0xFF3B3540),
    mark: MarkStyle.none,
    markColor: _cream,
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  /// 행성 풍선을 들고 둥둥 뜬 삼색.
  static const pungseon = CatSpec(
    id: 'pungseon',
    name: '풍선',
    body: _cream,
    mark: MarkStyle.earPatch,
    markColor: _ginger,
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  /// 달 해먹에 누워 별을 안은 샴.
  static const haemak = CatSpec(
    id: 'haemak',
    name: '해먹',
    body: _cream,
    mark: MarkStyle.sidePatch,
    markColor: Color(0xFF6B4F45),
    eyes: EyeStyle.open,
    charm: CatCharm.zzz,
  );

  /// 달 위에서 별을 이어 별자리를 만드는 두 마리.
  static const byeolit = CatSpec(
    id: 'byeolit',
    name: '별잇기',
    body: _grey,
    mark: MarkStyle.greyCap,
    markColor: _grey,
    eyes: EyeStyle.wink,
    charm: CatCharm.sparkle,
  );

  static const all = <CatSpec>[
    mochi,
    dalgi,
    byeol,
    sol,
    nabi,
    kongi,
    haneul,
    bori,
    mongi,
    dalrae,
    danchu,
    ujoo,
    byeoltong,
    dalbit,
    eunha,
    choco,
    pyeonji,
    cho,
    byeol2,
    usubu,
    got,
    rocket,
    byeoljari,
    nakksi,
    yuribyeong,
    wiseong,
    pungseon,
    haemak,
    byeolit,
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
    this.scale = 1,
  });
  final CatSpec spec;
  final double width;
  final double opacity;
  final Color? tint;

  /// 우주 고양이에 더 곱하는 배수. 옅게 깔 때처럼 카드에 넓게 놓이는 자리에서
  /// 키운 크기를 도로 줄이는 데 쓴다. 기존 고양이는 이 값을 무시한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isSpace = OriginalArtwork.spaceCats.contains(spec.id);
    final art = OriginalArtwork(
      art: spec.id,
      width: isSpace ? width * scale : width,
    );
    return opacity >= 1 ? art : Opacity(opacity: opacity, child: art);
  }
}
