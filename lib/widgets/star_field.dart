import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A fixed constellation whose stars brighten independently of one another.
class StarField extends StatefulWidget {
  const StarField({super.key});

  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  bool _reduceMotion = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_active && !_reduceMotion && TickerMode.valuesOf(context).enabled) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(child: CustomPaint(painter: _StarPainter(_clock))),
    ),
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;
  Size? _size;
  List<_Star> _stars = [];

  @override
  void paint(Canvas canvas, Size size) {
    if (_size != size) {
      _size = size;
      final random = math.Random(20260919);
      final count = (size.width * size.height / 100000 * 10.5).round();
      _stars = List.generate(
        count,
        (i) => _Star(
          Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
          ),
          random.nextDouble(),
          random.nextDouble() * math.pi * 2,
          4 + random.nextInt(5),
          i % 9 == 0,
        ),
      );
    }
    final paint = Paint();
    for (final star in _stars) {
      // Integer cycles make the 24-second loop seamless; each star takes 3–6s.
      final wave =
          (1 + math.sin(clock.value * math.pi * 2 * star.cycles + star.phase)) /
          2;
      final pulse = wave * wave;
      final radius = .5 + star.brightness * .8;
      final alpha = .14 + star.brightness * .18 + pulse * .48;
      if (star.sparkle) {
        final reach = 2.5 + pulse * 4;
        final halo = reach * 2.2;
        paint.shader = RadialGradient(
          colors: [
            const Color(0xFF9FC9FF).withValues(alpha: .10 + pulse * .16),
            const Color(0x009FC9FF),
          ],
        ).createShader(Rect.fromCircle(center: star.at, radius: halo));
        canvas.drawCircle(star.at, halo, paint);
        paint.shader = null;
        paint.color = const Color(0xFFD5E8FF).withValues(alpha: alpha);
        final x = star.at.dx;
        final y = star.at.dy;
        final core = .45 + pulse * .35;
        final rays = Path()
          ..moveTo(x, y - reach)
          ..lineTo(x + core, y - core)
          ..lineTo(x + reach * .8, y)
          ..lineTo(x + core, y + core)
          ..lineTo(x, y + reach)
          ..lineTo(x - core, y + core)
          ..lineTo(x - reach * .8, y)
          ..lineTo(x - core, y - core)
          ..close();
        canvas.drawPath(rays, paint);
      }
      paint.color = const Color(0xFFEEF5FF).withValues(alpha: alpha);
      canvas.drawCircle(star.at, radius * (.85 + pulse * .25), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.clock != clock;
}

class _Star {
  const _Star(this.at, this.brightness, this.phase, this.cycles, this.sparkle);

  final Offset at;
  final double brightness;
  final double phase;
  final int cycles;
  final bool sparkle;
}
