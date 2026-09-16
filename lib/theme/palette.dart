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
  });

  final String key;
  final String label;
  final Color bg; // 카드 바탕
  final Color ink; // 제목·본문 글자
  final Color line; // 괘선·체크박스 테두리
  final Color tint; // 강조 (+ 버튼, 체크 표시)

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

  static const all = <CardPalette>[
    blossom,
    apricot,
    sky,
    lilac,
    mint,
    butter,
  ];

  static CardPalette byKey(String key) =>
      all.firstWhere((p) => p.key == key, orElse: () => blossom);
}

/// 카드 제목 옆에 붙는 작은 표시. 카드 색과 따로 고를 수 있어야
/// 컨셉아트처럼 라일락 카드에 노란 전구를 둘 수 있다.
class CardBadge {
  const CardBadge({
    required this.key,
    required this.icon,
    required this.color,
  });

  final String key;
  final IconData icon;
  final Color color;

  static const all = <CardBadge>[
    CardBadge(key: 'heart', icon: Icons.favorite, color: Color(0xFFEE8F9F)),
    CardBadge(key: 'sprout', icon: Icons.eco, color: Color(0xFF86C08A)),
    CardBadge(key: 'moon', icon: Icons.nightlight_round, color: Color(0xFF7C9BD8)),
    CardBadge(key: 'bulb', icon: Icons.lightbulb, color: Color(0xFFEFC75E)),
    CardBadge(
      key: 'smile',
      icon: Icons.sentiment_satisfied_alt,
      color: Color(0xFF6FB07C),
    ),
    CardBadge(key: 'star', icon: Icons.star_rounded, color: Color(0xFFE9B85C)),
    CardBadge(key: 'paw', icon: Icons.pets, color: Color(0xFFC9A08E)),
    CardBadge(key: 'cloud', icon: Icons.cloud, color: Color(0xFF9FC2E0)),
    // 두 번째 장에서 쓰는 것들.
    CardBadge(
      key: 'spark',
      icon: Icons.auto_awesome,
      color: Color(0xFFF2A0AE),
    ),
    CardBadge(
      key: 'flower',
      icon: Icons.local_florist,
      color: Color(0xFFB39BD8),
    ),
    CardBadge(
      key: 'clover',
      icon: Icons.filter_vintage,
      color: Color(0xFF8FBF87),
    ),
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
  });

  final String key;
  final String label;
  final Color top;
  final Color bottom;
  final bool isDark;

  Color get onBackground =>
      isDark ? const Color(0xFFF3EEF6) : const Color(0xFF6B4F52);
  Color get onBackgroundMuted =>
      isDark ? const Color(0x8AF3EEF6) : const Color(0x8A8E7A72);

  /// 제목을 감싸는 구름 색.
  Color get cloud => isDark
      ? Colors.white.withValues(alpha: .10)
      : const Color(0xFFF6EADF).withValues(alpha: .95);

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
  static const night = BackgroundTheme(
    key: 'night',
    label: '밤하늘',
    top: Color(0xFF2E2B3A),
    bottom: Color(0xFF1D1B26),
    isDark: true,
  );

  static const all = <BackgroundTheme>[
    paper,
    cream,
    peach,
    lavender,
    mint,
    sky,
    cocoa,
    night,
  ];

  static BackgroundTheme byKey(String key) =>
      all.firstWhere((b) => b.key == key, orElse: () => paper);
}
