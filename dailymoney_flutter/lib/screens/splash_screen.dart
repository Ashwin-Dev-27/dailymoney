import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class _Particle {
  _Particle(this.rng)
      : depth = rng.nextDouble(),
        angle = rng.nextDouble() * math.pi * 2,
        radius = 90 + rng.nextDouble() * 150,
        speed = 0.6 + rng.nextDouble() * 1.4,
        size = 1.0 + rng.nextDouble() * 2.2,
        hueShift = rng.nextDouble();
  final math.Random rng;
  final double depth;
  double angle;
  final double radius;
  final double speed;
  final double size;
  final double hueShift;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final List<_Particle> _particles;
  final math.Random _rng = math.Random(42);
  bool _navigated = false;
  bool _reduced = false;
  bool _initialized = false;
  bool _showSkip = false;
  bool _firstLaunch = true;
  bool _simplified = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _reduced = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _particles = List.generate(_reduced ? 18 : 52, (_) => _Particle(_rng));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final settings = context.read<SettingsProvider>();
    _enabled = settings.splashIntroEnabled;
    _firstLaunch = !settings.splashIntroSeen;
    _simplified = !_firstLaunch;

    if (!_enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
      return;
    }

    final duration = _firstLaunch
        ? const Duration(milliseconds: 9000)
        : const Duration(milliseconds: 3500);
    final reducedDuration =
        _reduced ? const Duration(milliseconds: 420) : duration;

    _controller = AnimationController(vsync: this, duration: reducedDuration);
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _finish();
      }
    });

    // Show skip after a short delay.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && !_navigated) setState(() => _showSkip = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller!.forward();
    });
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    final settings = context.read<SettingsProvider>();
    settings.markSplashIntroSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const WelcomeGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const WelcomeGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _skip() {
    _controller?.stop();
    _finish();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double _smooth(double t, double a, double b) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    final x = (t - a) / (b - a);
    return x * x * (3 - 2 * x);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = _controller;
    if (ctrl == null) {
      // Disabled intro: blank dark frame until navigation completes.
      return const Scaffold(backgroundColor: Color(0xFF020617));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: ctrl,
            builder: (context, _) {
              final t = ctrl.value;
              final awaken = _smooth(t, 0.0, 0.2);
              final motion = _smooth(t, 0.15, 0.55);
              final form = _smooth(t, 0.45, 0.82);
              final brand = _smooth(t, 0.72, 0.92);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 1.15,
                        colors: isDark
                            ? const [
                                Color(0xFF0B1F3A),
                                Color(0xFF020617),
                                Color(0xFF000000),
                              ]
                            : const [
                                Color(0xFF0F172A),
                                Color(0xFF020617),
                                Color(0xFF000000),
                              ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _SplashPainter(
                      t: t,
                      particles: _particles,
                      reduced: _reduced,
                      awaken: awaken,
                      motion: motion,
                      form: form,
                      firstLaunch: _firstLaunch,
                      simplified: _simplified,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: _reduced ? 0 : 120),
                        Opacity(
                          opacity: brand,
                          child: Transform.translate(
                            offset: Offset(0, (1 - brand) * 14),
                            child: Text(
                              'DailyMoney',
                              style: TextStyle(
                                fontFamily: kFontFamily,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color:
                                        AppColors.brand.withValues(alpha: 0.45),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: _smooth(t, 0.78, 0.95),
                          child: const Text(
                            'Your Money. Your Control.',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 150,
                          height: 2,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: _smooth(t, 0.82, 0.98),
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.brand.withValues(alpha: 0.0),
                                      AppColors.brand,
                                      AppColors.brand.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // No extra blank hold; transition follows completion.
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showSkip ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: TextButton(
                onPressed: _showSkip ? _skip : null,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.t,
    required this.particles,
    required this.reduced,
    required this.awaken,
    required this.motion,
    required this.form,
    required this.firstLaunch,
    required this.simplified,
  });

  final double t;
  final List<_Particle> particles;
  final bool reduced;
  final double awaken;
  final double motion;
  final double form;
  final bool firstLaunch;
  final bool simplified;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 30);

    if (!reduced && !simplified) {
      final linePaint = Paint()
        ..color = AppColors.brand.withValues(alpha: 0.05 * motion)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 6; i++) {
        final x = size.width * (0.15 + i * 0.13);
        final path = Path()
          ..moveTo(x, size.height * 0.85)
          ..lineTo(x + 40, size.height * 0.15);
        canvas.drawPath(path, linePaint);
      }
    }

    if (!reduced && !simplified) {
      final trailColors = [
        AppColors.brand,
        const Color(0xFFFFFFFF),
        AppColors.brand,
      ];
      for (int i = 0; i < 3; i++) {
        final path = Path();
        final startX = i == 1 ? size.width * 0.9 : size.width * 0.1;
        final startY = size.height * (0.2 + i * 0.25);
        path.moveTo(startX, startY);
        path.cubicTo(
          size.width * 0.35,
          size.height * (0.1 + i * 0.1),
          size.width * 0.65,
          size.height * (0.9 - i * 0.1),
          center.dx,
          center.dy,
        );
        final paint = Paint()
          ..color = trailColors[i].withValues(alpha: 0.12 * motion)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(path, paint);

        final metric = path.computeMetrics().first;
        final pos = metric
            .getTangentForOffset(metric.length * motion.clamp(0.0, 1.0))
            ?.position;
        if (pos != null) {
          canvas.drawCircle(
            pos,
            2.2,
            Paint()..color = trailColors[i].withValues(alpha: 0.7 * motion),
          );
        }
      }
    }

    if (!simplified) {
      for (final p in particles) {
        double px, py;
        double opacity;
        if (t < 0.5) {
          final a = p.angle + p.speed * t * math.pi * 2;
          final r = p.radius * (1 - 0.15 * p.depth);
          px = center.dx + math.cos(a) * r;
          py = center.dy + math.sin(a) * r * 0.75;
          opacity = awaken * (0.35 + 0.5 * p.depth);
        } else {
          final conv = _smoothStatic(t, 0.5, 0.82);
          final a = p.angle + p.speed * 0.5 * math.pi * 2;
          final r = p.radius * (1 - conv);
          px = center.dx + math.cos(a) * r * (1 - conv);
          py = center.dy + math.sin(a) * r * 0.75 * (1 - conv);
          opacity = awaken * (1 - conv) * (0.35 + 0.5 * p.depth);
        }
        final color = Color.lerp(
          AppColors.brand,
          Colors.white,
          p.hueShift * 0.4,
        )!;
        canvas.drawCircle(
          Offset(px, py),
          p.size,
          Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        );
      }
    } // simplified

    if (form > 0) {
      final markOpacity = form;
      final scale = 0.7 + 0.3 * form;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);

      final ringPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.0),
            AppColors.brand.withValues(alpha: 0.9 * markOpacity),
            AppColors.brand.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(t * math.pi * 2),
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 52))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(Offset.zero, 52, ringPaint);

      final innerPaint = Paint()
        ..color = AppColors.brand.withValues(alpha: 0.35 * markOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset.zero, 36, innerPaint);

      final arrowPath = Path()
        ..moveTo(-14, 18)
        ..lineTo(0, -22)
        ..lineTo(14, 18);
      final arrowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.brand.withValues(alpha: 0.4 * markOpacity),
            Colors.white.withValues(alpha: 0.95 * markOpacity),
          ],
        ).createShader(const Rect.fromLTWH(-14, -22, 28, 40))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(arrowPath, arrowPaint);

      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * markOpacity),
      );

      final sweepOpacity =
          _smoothStatic(t, 0.62, 0.9) * (1 - _smoothStatic(t, 0.92, 1.0));
      if (sweepOpacity > 0) {
        canvas.drawCircle(
          Offset(
              52 * math.cos(t * math.pi * 4), 52 * math.sin(t * math.pi * 4)),
          6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * sweepOpacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      canvas.restore();

      canvas.drawCircle(
        center,
        70,
        Paint()
          ..color = AppColors.brand.withValues(alpha: 0.12 * markOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  static double _smoothStatic(double t, double a, double b) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    final x = (t - a) / (b - a);
    return x * x * (3 - 2 * x);
  }

  @override
  bool shouldRepaint(covariant _SplashPainter oldDelegate) => true;
}
