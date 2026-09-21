import 'package:flutter/material.dart';

/// 카드 한 장의 색 묶음. 바탕·글자·괘선이 항상 한 세트로 움직여야
/// 배경을 바꿔도 대비가 무너지지 않는다.
class CardPalette {
  const CardPalette({
    required this.key,
    required this.label,
    required this.bg,
    required this.ink,
    required this.line,
    required this.tint,
    this.night = false,
  });

  final String key;
  final String label;
  final Color bg; // 카드 바탕
  final Color ink; // 제목·본문 글자
  final Color line; // 괘선·체크박스 테두리
  final Color tint; // 강조 (+ 버튼, 체크 표시)

  /// 밤하늘 위에서 쓰는 모습인지. 체크 표시처럼 바탕에 따라 색이 갈리는 곳이 본다.
  final bool night;

  /// 밤하늘 위에 놓일 때의 모습. 카드는 반투명한 남색 박스가 되어 파스텔
  /// 바탕을 깔지 않으므로, 글자·괘선·강조를 카드 색의 밝은 짝으로 바꾼다.
  /// 어느 카드인지는 바탕이 아니라 이 색으로 알아본다.
  CardPalette onNight() => CardPalette(
    key: key,
    label: label,
    bg: bg,
    ink: nightInk,
    line: nightInk.withValues(alpha: .24),
    tint: nightInk,
    night: true,
  );

  /// 밤하늘 위에 놓일 때 쓰는 글자색. [ink] 는 밝은 카드 바탕을 전제로 한
  /// 짙은 색이라, 남색 위에 그대로 얹으면 글씨가 묻힌다. 카드 색을 그대로
  /// 알아볼 수 있도록 같은 색의 밝은 짝을 따로 둔다.
  Color get nightInk => switch (key) {
    'apricot' => const Color(0xFFF2C98A),
    'sky' => const Color(0xFF94C0E8),
    'lilac' => const Color(0xFFBCAEEA),
    'mint' => const Color(0xFF9BD8AE),
    'butter' => const Color(0xFFFFE59B),
    'white' => const Color(0xFFE8E1E3),
    _ => const Color(0xFFF3AFC4),
  };

  /// 배경에 따라 고르는 글자색.
  Color inkOn(bool isDark) => isDark ? nightInk : ink;

  static const blossom = CardPalette(
    key: 'blossom',
    label: '벚꽃',
    bg: Color(0xFFFBDCE5),
    ink: Color(0xFF6E4F55),
    line: Color(0xFFEFC2D0),
    tint: Color(0xFFE88BA4),
  );
  static const apricot = CardPalette(
    key: 'apricot',
    label: '살구',
    bg: Color(0xFFFCE4C0),
    ink: Color(0xFF7B6141),
    line: Color(0xFFF1D2A3),
    tint: Color(0xFFE0A855),
  );
  static const sky = CardPalette(
    key: 'sky',
    label: '하늘',
    bg: Color(0xFFD0E3F8),
    ink: Color(0xFF4E6480),
    line: Color(0xFFB6D1EF),
    tint: Color(0xFF6E9BD0),
  );
  static const lilac = CardPalette(
    key: 'lilac',
    label: '라일락',
    bg: Color(0xFFDFD6F5),
    ink: Color(0xFF63568A),
    line: Color(0xFFCBBFEC),
    tint: Color(0xFF8F7FC8),
  );
  static const mint = CardPalette(
    key: 'mint',
    label: '민트',
    bg: Color(0xFFD4EEDA),
    ink: Color(0xFF4E7458),
    line: Color(0xFFBBE1C5),
    tint: Color(0xFF6EAE80),
  );
  static const butter = CardPalette(
    key: 'butter',
    label: '버터',
    bg: Color(0xFFFCEBC1),
    ink: Color(0xFF7C6640),
    line: Color(0xFFF1DEA6),
    tint: Color(0xFFD8B95C),
  );

  /// 아무 색도 얹지 않은 카드. 글씨만 남기고 싶을 때 쓴다.
  static const white = CardPalette(
    key: 'white',
    label: '화이트',
    bg: Color(0xFFFFFFFF),
    ink: Color(0xFF6B5B5E),
    line: Color(0xFFE6DFE1),
    tint: Color(0xFFC9B6BB),
  );

  static const all = <CardPalette>[
    blossom,
    apricot,
    sky,
    lilac,
    mint,
    butter,
    white,
  ];

  static CardPalette byKey(String key) =>
      all.firstWhere((p) => p.key == key, orElse: () => blossom);
}

/// 카드 제목 옆에 붙는 작은 표시. 카드 색과 따로 고를 수 있어야
/// 컨셉아트처럼 라일락 카드에 노란 전구를 둘 수 있다.
class CardBadge {
  const CardBadge({required this.key, required this.icon, required this.color});

  final String key;

  /// 아무 표시도 두지 않는 '없음' 은 그림이 없다.
  final IconData? icon;
  final Color color;

  static const all = <CardBadge>[
    CardBadge(key: 'heart', icon: Icons.favorite, color: Color(0xFFEE8F9F)),
    CardBadge(key: 'sprout', icon: Icons.eco, color: Color(0xFF86C08A)),
    CardBadge(
      key: 'moon',
      icon: Icons.nightlight_round,
      color: Color(0xFF7C9BD8),
    ),
    CardBadge(key: 'bulb', icon: Icons.lightbulb, color: Color(0xFFEFC75E)),
    CardBadge(
      key: 'smile',
      icon: Icons.sentiment_satisfied_alt,
      color: Color(0xFF6FB07C),
    ),
    CardBadge(key: 'star', icon: Icons.star_rounded, color: Color(0xFFE9B85C)),
    CardBadge(key: 'paw', icon: Icons.pets, color: Color(0xFFC9A08E)),
    CardBadge(key: 'cloud', icon: Icons.cloud, color: Color(0xFF9FC2E0)),
    // 두 번째 장에서 쓰는 것.
    CardBadge(key: 'spark', icon: Icons.auto_awesome, color: Color(0xFFF2A0AE)),
    // 제목 옆을 비워 두고 싶을 때.
    CardBadge(key: 'none', icon: null, color: Color(0x00000000)),
  ];

  static CardBadge byKey(String key) =>
      all.firstWhere((b) => b.key == key, orElse: () => all.first);
}

/// 앱 전체 배경. 사용자가 자유롭게 바꾼다.
class BackgroundTheme {
  const BackgroundTheme({
    required this.key,
    required this.label,
    required this.top,
    required this.bottom,
    this.isDark = false,
    this.starry = false,
  });

  final String key;
  final String label;
  final Color top;
  final Color bottom;
  final bool isDark;

  /// 바탕 위에 별을 뿌릴지.
  final bool starry;

  Color get onBackground =>
      isDark ? const Color(0xFFF3EEF6) : const Color(0xFF6B4F52);
  Color get onBackgroundMuted =>
      isDark ? const Color(0x8AF3EEF6) : const Color(0x8A8E7A72);

  /// 제목을 감싸는 구름 색.
  Color get cloud => isDark
      ? Colors.white.withValues(alpha: .07)
      : const Color(0xFFF6EADF).withValues(alpha: .95);

  /// 블록·검색칸이 깔고 앉는 바탕. 어두울 때는 하늘빛이 살짝 도는 남색이라
  /// 배경에서 한 겹 떠 보인다.
  Color get panel => isDark
      ? const Color(0xFF7FB2E8).withValues(alpha: .10)
      : Colors.white.withValues(alpha: .45);

  /// 목록 페이지의 블록·검색칸·단추가 까는 바탕. 밤하늘에서는 하늘빛 남색을 반투명
  /// (50%)으로 깔아 뒤의 별이 비친다. 메모 페이지의 카드는 이것이 아니라 불투명한
  /// 박스를 쓴다. 밤하늘이 아니면 [panel] 과 같다.
  Color get listPanel =>
      isDark ? const Color(0xFF3B5A88).withValues(alpha: .5) : panel;

  /// 메모 페이지 카드가 까는 불투명한 남색. 목록의 반투명 블록(뒤의 하늘이 섞여
  /// 약 #223653)보다 한 단계 밝아, 카드가 하늘과 또렷이 갈린다.
  static const memoBox = Color(0xFF2A3A55);

  /// 그 바탕을 두르는 테두리.
  Color get panelEdge => isDark
      ? Colors.white.withValues(alpha: .16)
      : Colors.white.withValues(alpha: .8);

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );

  /// 컨셉아트의 기본 배경 — 거의 흰색에 아주 옅은 따뜻함.
  static const paper = BackgroundTheme(
    key: 'paper',
    label: '종이',
    top: Color(0xFFF2DFD4),
    bottom: Color(0xFFE2D6E9),
  );
  static const cream = BackgroundTheme(
    key: 'cream',
    label: '크림',
    top: Color(0xFFFDF6E9),
    bottom: Color(0xFFF6E7D4),
  );
  static const peach = BackgroundTheme(
    key: 'peach',
    label: '복숭아',
    top: Color(0xFFFDEDE4),
    bottom: Color(0xFFF7DBD1),
  );
  static const lavender = BackgroundTheme(
    key: 'lavender',
    label: '라벤더',
    top: Color(0xFFF1ECFB),
    bottom: Color(0xFFE2D9F5),
  );
  static const mint = BackgroundTheme(
    key: 'mint',
    label: '민트',
    top: Color(0xFFE9F7ED),
    bottom: Color(0xFFD6ECE0),
  );
  static const sky = BackgroundTheme(
    key: 'sky',
    label: '하늘',
    top: Color(0xFFE9F3FB),
    bottom: Color(0xFFD8E8F7),
  );
  static const cocoa = BackgroundTheme(
    key: 'cocoa',
    label: '코코아',
    top: Color(0xFFF3EAE2),
    bottom: Color(0xFFE3D5C8),
  );

  /// 별이 뜨는 남색 하늘. 이 배경만 바탕 위에 별을 뿌린다.
  static const night = BackgroundTheme(
    key: 'night',
    label: '밤하늘',
    top: Color(0xFF0A1730),
    bottom: Color(0xFF081226),
    isDark: true,
    starry: true,
  );

  /// 위는 온전한 흰색, 아래로 갈수록 살짝 따뜻해지는 오프화이트.
  /// 이름은 '웜화이트'로 바뀌었지만 열쇠는 그대로 둔다 — 바꾸면 이미
  /// 이 배경을 골라 둔 기기가 처음 배경으로 되돌아간다.
  static const white = BackgroundTheme(
    key: 'white',
    label: '웜화이트',
    top: Color(0xFFFFFFFF),
    bottom: Color(0xFFF4F0EC),
  );

  /// 같은 흰색이되 아래로 갈수록 은빛이 도는 회백색. 파랑 기를 빼고
  /// 세 색을 나란히 두어 강철이나 은처럼 중립적인 잿빛이 된다. 처음
  /// 까는 기기의 기본 배경이다.
  static const coolWhite = BackgroundTheme(
    key: 'coolWhite',
    label: '쿨화이트',
    top: Color(0xFFFFFFFF),
    bottom: Color(0xFFDEDEDD),
  );

  static const all = <BackgroundTheme>[
    paper,
    white,
    coolWhite,
    cream,
    peach,
    lavender,
    mint,
    sky,
    cocoa,
    night,
  ];

  static BackgroundTheme byKey(String key) =>
      all.firstWhere((b) => b.key == key, orElse: () => coolWhite);
}

/// 창과 단추가 함께 쓰는 잿빛 결. 카드 꾸미기 창에서 다듬은 모습을 그대로
/// 앱의 기본으로 삼았다. 고른 것은 색 테두리가 아니라 옅은 음영으로만
/// 보이니, 카드 색 견본 옆에서도 창이 조용하다.
class AppTone {
  const AppTone._();

  /// 창 바탕. 노란 기를 뺀 중립 회백색이라 위에 놓인 색이 제 색으로 보인다.
  static const sheet = Color(0xFFF8F8F7);

  /// 고른 칸과 글칸에 까는 옅은 음영.
  static const picked = Color(0x12000000);

  /// 고르지 않은 칸을 두르는 옅은 잿빛 테두리.
  static const idleEdge = Color(0x1A000000);

  /// 창 안 글씨에 쓰는 먹빛.
  static const ink = Color(0xFF6B4F52);

  /// 단추 바탕에 쓰는 쿨화이트.
  static const buttonFill = Color(0xFFF7F7F6);

  /// 단추를 두르는 검은 테두리. 창 안에서 여기만 검어서 눈이 먼저 간다.
  static const buttonEdge = Color(0xFF1C1B1B);

  /// 창 안 칸과 단추가 함께 쓰는 모서리.
  static const radius = 14.0;
}
