import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// Shared dimensions and translucent surface for both page footers.
class BottomBarSurface extends StatelessWidget {
  const BottomBarSurface({super.key, required this.bg, required this.child});
  final BackgroundTheme bg;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: bg.isDark ? bg.listPanel : Colors.white.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: bg.panelEdge),
    ),
    child: child,
  );
}
