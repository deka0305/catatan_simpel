import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'db_helper.dart';
import 'package:intl/intl.dart';

// Custom wave clipper for app bar
class _WaveAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// === Fancy animated sky elements (Sun / Moon / Clouds / Shooting star) ===

class _SunRaysPainter extends CustomPainter {
  final Color color;
  final int rays;
  _SunRaysPainter({required this.color, this.rays = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rInner = size.shortestSide * 0.32;
    final rOuter = size.shortestSide * 0.48;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < rays; i++) {
      final a = (2 * math.pi / rays) * i;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * rInner;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * rOuter;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.rays != rays;
  }
}

class _HedonSun extends StatefulWidget {
  final double size; // logical pixels of the whole widget
  const _HedonSun({Key? key, this.size = 96}) : super(key: key);

  @override
  State<_HedonSun> createState() => _HedonSunState();
}

class _HedonSunState extends State<_HedonSun>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _rot = Tween<double>(begin: 0, end: 2 * math.pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer glow
          Container(
            width: size * 1.3,
            height: size * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFF59D).withOpacity(0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Rotating rays
          AnimatedBuilder(
            animation: _rot,
            builder: (context, _) => Transform.rotate(
              angle: _rot.value,
              child: CustomPaint(
                size: Size.square(size),
                painter: _SunRaysPainter(
                  color: Colors.white.withOpacity(0.55),
                  rays: 18,
                ),
              ),
            ),
          ),
          // Core disc
          Container(
            width: size * 0.46,
            height: size * 0.46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFFDE7), Color(0xFFFFD54F)],
                stops: [0.1, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: Color(0x66FFC107), blurRadius: 16, spreadRadius: 4),
              ],
            ),
          ),
          // Tiny orbiting flare dot
          AnimatedBuilder(
            animation: _rot,
            builder: (context, _) {
              final r = size * 0.36;
              final dx = math.cos(-_rot.value) * r;
              final dy = math.sin(-_rot.value) * r;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]),
                    boxShadow: const [
                      BoxShadow(color: Colors.white70, blurRadius: 6, spreadRadius: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoonCratersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final base = Offset(size.width / 2, size.height / 2);
    final craters = <Offset>[
      base + Offset(-size.width * 0.18, -size.height * 0.12),
      base + Offset(size.width * 0.10, -size.height * 0.20),
      base + Offset(size.width * 0.20, size.height * 0.10),
      base + Offset(-size.width * 0.12, size.height * 0.16),
    ];
    for (final c in craters) {
      paint.color = const Color(0xFFB0BEC5);
      canvas.drawCircle(c, size.shortestSide * 0.08, paint);
      paint.color = const Color(0xFF90A4AE);
      canvas.drawCircle(c + const Offset(2, 2), size.shortestSide * 0.05, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HedonMoon extends StatefulWidget {
  final double size;
  const _HedonMoon({Key? key, this.size = 84}) : super(key: key);

  @override
  State<_HedonMoon> createState() => _HedonMoonState();
}

class _HedonMoonState extends State<_HedonMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final dy = lerpDouble(-3, 3, _ctrl.value) ?? 0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer night glow
                Container(
                  width: size * 1.25,
                  height: size * 1.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF9FA8DA).withOpacity(0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Moon disc with gradient
                Container(
                  width: size * 0.56,
                  height: size * 0.56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFECEFF1), Color(0xFFB0BEC5)],
                      center: Alignment(-0.3, -0.3),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x3390A4AE), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                ),
                // Craters
                CustomPaint(
                  size: Size.square(size * 0.56),
                  painter: _MoonCratersPainter(),
                ),
                // Thin crescent highlight overlay
                IgnorePointer(
                  child: Container(
                    width: size * 0.58,
                    height: size * 0.58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.transparent,
                        ],
                        startAngle: -0.5,
                        endAngle: 0.7,
                        center: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloudShape extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  const _CloudShape({Key? key, required this.width, required this.height, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: width * 0.05,
            top: height * 0.35,
            right: width * 0.05,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height * 0.3),
              ),
            ),
          ),
          Positioned(
            left: width * 0.18,
            top: height * 0.05,
            child: Container(
              width: width * 0.38,
              height: height * 0.65,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height * 0.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
          Positioned(
            left: width * 0.4,
            top: 0,
            child: Container(
              width: width * 0.34,
              height: height * 0.62,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height * 0.5),
              ),
            ),
          ),
          Positioned(
            left: width * 0.02,
            top: height * 0.12,
            child: Container(
              width: width * 0.32,
              height: height * 0.52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height * 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParallaxCloud extends StatefulWidget {
  final double width;
  final double height;
  final Duration duration;
  final double dx; // horizontal travel
  final double start;
  final Color color;
  const _ParallaxCloud({
    Key? key,
    required this.width,
    required this.height,
    required this.duration,
    required this.dx,
    required this.start,
    required this.color,
  }) : super(key: key);

  @override
  State<_ParallaxCloud> createState() => _ParallaxCloudState();
}

class _ParallaxCloudState extends State<_ParallaxCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final offset = lerpDouble(-widget.dx, widget.dx, t) ?? 0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: _CloudShape(
            width: widget.width,
            height: widget.height,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _ShootingStar extends StatefulWidget {
  final Duration duration;
  final Alignment begin;
  final Alignment end;
  const _ShootingStar({Key? key, this.duration = const Duration(seconds: 3), this.begin = const Alignment(1.2, -0.9), this.end = const Alignment(-1.2, -0.3)}) : super(key: key);

  @override
  State<_ShootingStar> createState() => _ShootingStarState();
}

class _ShootingStarState extends State<_ShootingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _scheduleNext();
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    final delay = Duration(milliseconds: 700 + math.Random().nextInt(2200));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeOutQuart.transform(_ctrl.value);
        final x = lerpDouble(widget.begin.x, widget.end.x, t)!;
        final y = lerpDouble(widget.begin.y, widget.end.y, t)!;
        return Align(
          alignment: Alignment(x, y),
          child: Transform.rotate(
            angle: -math.pi / 6,
            child: Container(
              width: 56,
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.white70, blurRadius: 4, spreadRadius: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class UsahaPage extends StatefulWidget {
  const UsahaPage({Key? key}) : super(key: key);

  @override
  State<UsahaPage> createState() => _UsahaPageState();
}

class _UsahaPageState extends State<UsahaPage> {
  List<Map<String, dynamic>> usahaFolders = [];
  final NumberFormat _idrFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Animation toggles for subtle twinkle effects at night
  bool _twinkle1Reverse = false;
  bool _twinkle2Reverse = true;
  bool _isLoadingFolders = true;
  StreamSubscription<void>? _remoteChangeSub;

  // Cache for per-folder kas list futures to avoid flicker on rebuilds
  final Map<int, Future<List<Map<String, dynamic>>>> _kasFutureCache = {};

  Future<List<Map<String, dynamic>>> _getKasListFuture(int folderId) {
    return _kasFutureCache.putIfAbsent(
        folderId, () => DatabaseHelper.instance.getUsahaKasList(folderId));
  }

  // Helper: determine time phase for theming
  String _getPhase([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    final h = now.hour;
    if (h >= 19 || h < 5) return 'night';
    if (h >= 5 && h < 8) return 'dawn';
    if (h >= 17 && h < 19) return 'dusk';
    return 'day';
  }

  // Helper: greeting text by time
  String _greetingText([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    final h = now.hour;
    if (h >= 4 && h < 11) return 'Selamat Pagi';
    if (h >= 11 && h < 15) return 'Selamat Siang';
    if (h >= 15 && h < 19) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _remoteChangeSub = DatabaseHelper.instance.onRemoteChange.listen((_) async {
      await _loadFolders();
    });
  }

  @override
  void dispose() {
    _remoteChangeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    if (mounted) setState(() => _isLoadingFolders = true);
    // Invalidate cached kas futures when (re)loading folders
    _kasFutureCache.clear();
    final data = await DatabaseHelper.instance.getUsahaFolders();
    if (mounted) {
      setState(() {
        usahaFolders = data;
        _isLoadingFolders = false;
      });
    }
  }

  // Small circular badge with time-based gradient and animated icon
  Widget _buildSkyBadge() {
    final now = DateTime.now();
    final h = now.hour;
    final bool isNight = h >= 19 || h < 5;
    final bool isDawn = h >= 5 && h < 8;
    final bool isDusk = h >= 17 && h < 19;
    final bool isDay = !isNight && !isDawn && !isDusk;

    // Gradients by time
    final List<Color> grad = isNight
        ? const [Color.fromARGB(255, 81, 121, 194), Color.fromARGB(255, 69, 121, 211)] // deep blue
        : isDawn
            ? const [Color(0xFFFFD194), Color(0xFF70E1F5)] // sunrise
            : isDusk
                ? const [Color(0xFFFFA5A5), Color(0xFF7F7FD5)] // sunset
                : const [Color(0xFFFFF19A), Color(0xFF7FD7FF)]; // bright day

    // Icon layer animation (replaced with fancy widgets)
    final Widget iconLayer = isNight
        ? const _HedonMoon(size: 22)
        : isDay
            ? const _HedonSun(size: 24)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: -5.0, end: 5.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(value, 0),
                  child: child,
                ),
                onEnd: () => setState(() {}),
                child: _CloudShape(
                  width: 26,
                  height: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              );

    // Twinkling stars for night
    final List<Widget> starWidgets = <Widget>[];
    if (isNight) {
      starWidgets.addAll([
        Positioned(
          left: 7,
          top: 8,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: _twinkle1Reverse ? 1.0 : 0.3,
              end: _twinkle1Reverse ? 0.3 : 1.0,
            ),
            duration: const Duration(milliseconds: 1500),
            onEnd: () => setState(() => _twinkle1Reverse = !_twinkle1Reverse),
            builder: (context, opacity, child) => Opacity(
              opacity: opacity,
              child: child,
            ),
            child: const Icon(Icons.star_rate_rounded,
                color: Colors.white, size: 6),
          ),
        ),
        Positioned(
          right: 7,
          bottom: 8,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: _twinkle2Reverse ? 1.0 : 0.3,
              end: _twinkle2Reverse ? 0.3 : 1.0,
            ),
            duration: const Duration(milliseconds: 1200),
            onEnd: () => setState(() => _twinkle2Reverse = !_twinkle2Reverse),
            builder: (context, opacity, child) => Opacity(
              opacity: opacity,
              child: child,
            ),
            child: const Icon(Icons.star_rate_rounded,
                color: Colors.white, size: 5),
          ),
        ),
      ]);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            width: 36,
            height: 36,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: grad),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          ...starWidgets,
          iconLayer,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(170),
        child: ClipPath(
          clipper: _WaveAppBarClipper(),
          child: Builder(
            builder: (context) {
              final now = DateTime.now();
              final h = now.hour;
              final bool isNight = h >= 19 || h < 5;
              final bool isDawn = h >= 5 && h < 8;
              final bool isDusk = h >= 17 && h < 19;
              final bool isDay = !isNight && !isDawn && !isDusk;

              final List<Color> headerGrad = isNight
                  ? const [Color.fromARGB(255, 31, 64, 78), Color.fromARGB(255, 61, 109, 126)] // deep night
                  : isDawn
                      ? const [Color(0xFFFFD194), Color(0xFF70E1F5)] // sunrise
                      : isDusk
                          ? const [
                              Color(0xFFFFA5A5),
                              Color(0xFF7F7FD5)
                            ] // sunset
                          : const [
                              Color(0xFFFFF19A),
                              Color(0xFF7FD7FF),
                            ]; // bright day

              return AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerGrad,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative sky overlay (non-interactive)
                    IgnorePointer(
                      child: SizedBox.expand(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Stack(
                            children: [
                              if (isDay) ...[
                                Align(
                                  alignment: const Alignment(0.9, -0.92),
                                  child: Opacity(
                                    opacity: 0.9,
                                    child: const _HedonSun(size: 96),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-0.9, -0.55),
                                  child: _ParallaxCloud(
                                    width: 110,
                                    height: 55,
                                    duration: const Duration(seconds: 5),
                                    dx: 24,
                                    start: -1.0,
                                    color: Colors.white.withOpacity(0.20),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(0.7, -0.25),
                                  child: _ParallaxCloud(
                                    width: 90,
                                    height: 46,
                                    duration: const Duration(seconds: 6),
                                    dx: 20,
                                    start: 1.0,
                                    color: Colors.white.withOpacity(0.16),
                                  ),
                                ),
                              ],
                              if (isDawn || isDusk) ...[
                                Align(
                                  alignment: const Alignment(0.85, -0.88),
                                  child: Opacity(
                                    opacity: 0.75,
                                    child: const _HedonSun(size: 84),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-1.1, -0.55),
                                  child: _ParallaxCloud(
                                    width: 120,
                                    height: 60,
                                    duration: const Duration(seconds: 4),
                                    dx: 30,
                                    start: -1.0,
                                    color: Colors.white.withOpacity(0.26),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(1.05, -0.2),
                                  child: _ParallaxCloud(
                                    width: 100,
                                    height: 52,
                                    duration: const Duration(seconds: 5),
                                    dx: 26,
                                    start: 1.0,
                                    color: Colors.white.withOpacity(0.22),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-0.2, -0.35),
                                  child: _ParallaxCloud(
                                    width: 80,
                                    height: 44,
                                    duration: const Duration(seconds: 6),
                                    dx: 18,
                                    start: 0.0,
                                    color: Colors.white.withOpacity(0.18),
                                  ),
                                ),
                              ],
                              if (isNight) ...[
                                Align(
                                  alignment: const Alignment(0.9, -0.86),
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: const _HedonMoon(size: 84),
                                  ),
                                ),
                                const _ShootingStar(),
                                // twinkles
                                Positioned(
                                  left: 28,
                                  top: 24,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.3, end: 1.0),
                                    duration: const Duration(milliseconds: 1400),
                                    onEnd: () => setState(() {}),
                                    builder: (context, o, _) => Opacity(
                                      opacity: o,
                                      child: const Icon(Icons.star_rate_rounded, color: Colors.white, size: 8),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 38,
                                  top: 18,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 1.0, end: 0.4),
                                    duration: const Duration(milliseconds: 1200),
                                    onEnd: () => setState(() {}),
                                    builder: (context, o, _) => Opacity(
                                      opacity: o,
                                      child: const Icon(Icons.star_rate_rounded, color: Colors.white, size: 7),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 28,
                                  top: 64,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.4, end: 1.0),
                                    duration: const Duration(milliseconds: 1600),
                                    onEnd: () => setState(() {}),
                                    builder: (context, o, _) => Opacity(
                                      opacity: o,
                                      child: const Icon(Icons.star_rate_rounded, color: Colors.white, size: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date pill
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: 54,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('MMM')
                                            .format(DateTime.now())
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEDF2FB),
                                          fontSize: 12,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateTime.now()
                                            .day
                                            .toString()
                                            .padLeft(2, '0'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Title + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Keuangan',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF143D59),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_greetingText()} • Semangat berusaha!',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x33000000),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sky badge: gradient + icon berubah sesuai waktu
                            _buildSkyBadge(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          final phase = _getPhase();
          final List<Color> bodyGrad = phase == 'night'
              ? const [Color.fromARGB(255, 128, 159, 177), Color.fromARGB(255, 99, 133, 165)]
              : phase == 'dawn'
                  ? const [Color(0xFFFFEFBA), Color(0xFFFFFFD1)]
                  : phase == 'dusk'
                      ? const [Color(0xFFFFD1C1), Color(0xFFFFE6E6)]
                      : const [Color(0xFFFFF7D6), Color(0xFFE6F7FF)];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bodyGrad,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.02), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: _isLoadingFolders
                  ? Center(
                      key: const ValueKey('loading'),
                      child: CircularProgressIndicator(
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF143D59)),
                        backgroundColor:
                            const Color(0xFF143D59).withOpacity(0.15),
                      ),
                    )
                  : usahaFolders.isEmpty
                      ? const Center(
                          key: ValueKey('empty'),
                          child: Text('Belum ada folder.',
                              style: TextStyle(
                                  color: Color(0xFFB0A295), fontSize: 18)))
                      : RefreshIndicator(
                          key: const ValueKey('list'),
                          onRefresh: _loadFolders,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: usahaFolders.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              thickness: 0.6,
                              indent: 56,
                              endIndent: 12,
                            ),
                            itemBuilder: (context, index) {
                              final folder = usahaFolders[index];
                              return TweenAnimationBuilder<double>(
                                key: ValueKey('folder_${folder['id']}'),
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(
                                    milliseconds:
                                        300 + math.min(index * 35, 350)),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, child) => Opacity(
                                  opacity: v,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - v) * 12),
                                    child: child,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                      horizontal: -2, vertical: -2),
                                  minLeadingWidth: 0,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  leading: Hero(
                                    tag: 'folderIcon_${folder['id']}',
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 255, 255, 255),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.amber[700]!,
                                            width: 1),
                                      ),
                                      child: Icon(Icons.folder,
                                          color: const Color.fromARGB(
                                              255, 228, 166, 84),
                                          size: 22),
                                    ),
                                  ),
                                  title: Hero(
                                    tag: 'folderTitle_${folder['id']}',
                                    flightShuttleBuilder: (context, animation,
                                            direction, from, to) =>
                                        FadeTransition(
                                            opacity: animation,
                                            child: to.widget),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: Text(
                                        folder['nama'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                          color: Color(0xFF143D59),
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  subtitle:
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _getKasListFuture(
                                        (folder['id'] as int)),
                                    builder: (context, snapshot) {
                                      final waiting =
                                          snapshot.connectionState ==
                                              ConnectionState.waiting;
                                      if (waiting) {
                                        return AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Text(
                                            'Memuat...',
                                            key: ValueKey(
                                                'subtitle_${folder['id']}_loading'),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }
                                      final kas = snapshot.data ?? [];
                                      int pemasukan = kas
                                          .where(
                                              (k) => k['tipe'] == 'Pemasukan')
                                          .fold(
                                              0,
                                              (a, b) =>
                                                  a +
                                                  ((b['nominal'] ?? 0) as int));
                                      int pengeluaran = kas
                                          .where(
                                              (k) => k['tipe'] == 'Pengeluaran')
                                          .fold(
                                              0,
                                              (a, b) =>
                                                  a +
                                                  ((b['nominal'] ?? 0) as int));
                                      int saldo = pemasukan - pengeluaran;
                                      return AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        child: Text(
                                          'Kas ${kas.length} | Masuk ${_idrFormat.format(pemasukan)} | Keluar ${_idrFormat.format(pengeluaran)} | Saldo ${_idrFormat.format(saldo)}',
                                          key: ValueKey(
                                              'subtitle_${folder['id']}_ready_${kas.length}_${pemasukan}_${pengeluaran}_${saldo}'),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UsahaKasDetailPage(
                                                folderId: folder['id'],
                                                folderName: folder['nama']),
                                      ),
                                    );
                                    _loadFolders();
                                  },
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    iconSize: 18,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    splashRadius: 18,
                                    tooltip: 'Hapus Folder',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          backgroundColor:
                                              const Color(0xFFFFF5E4),
                                          title: const Text('Hapus Folder',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          content: Text(
                                              'Yakin ingin menghapus folder "${folder['nama']}"? Semua data kas di dalamnya juga akan dihapus.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Hapus',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await DatabaseHelper.instance
                                            .deleteUsahaFolder(folder['id']);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Folder dihapus')),
                                          );
                                        }
                                        _loadFolders();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final folderName = await showDialog<String>(
            context: context,
            builder: (context) {
              String tempName = '';
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                backgroundColor: const Color(0xFFFFF5E4),
                title: const Text('Tambah Folder',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                content: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nama folder',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) => tempName = value,
                ),
                actionsPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, tempName),
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          );
          if (folderName != null && folderName.trim().isNotEmpty) {
            await DatabaseHelper.instance.insertUsahaFolder(folderName.trim());
            _loadFolders();
          }
        },
        label: const Text('Folder Baru'),
        icon: const Icon(Icons.create_new_folder),
        backgroundColor: const Color(0xFFF4B41A),
        foregroundColor: const Color(0xFF143D59),
        tooltip: 'Tambah Folder',
      ),
    );
  }
}

class _FolderMiniIcon extends StatelessWidget {
  final double width;
  final double height;

  const _FolderMiniIcon({super.key, this.width = 44, this.height = 30});

  @override
  Widget build(BuildContext context) {
    const bodyColor = Color(0xFFFFD36E); // badan folder
    const tabColor = Color(0xFFFFE29C); // tab folder
    const borderColor = Color(0xFFF1C85A); // garis folder

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Badan folder
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: height * 0.28,
            child: Container(
              decoration: BoxDecoration(
                color: bodyColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Tab folder
          Positioned(
            left: width * 0.06,
            top: 0,
            width: width * 0.46,
            height: height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                color: tabColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              padding: const EdgeInsets.all(7),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final double? width;

  const _SummaryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bgGradient = LinearGradient(
      colors: [
        color.withOpacity(0.12),
        color.withOpacity(0.06),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UsahaKasDetailPage extends StatefulWidget {
  final int folderId;
  final String folderName;
  const UsahaKasDetailPage(
      {Key? key, required this.folderId, required this.folderName})
      : super(key: key);

  @override
  State<UsahaKasDetailPage> createState() => _UsahaKasDetailPageState();
}

class _UsahaKasDetailPageState extends State<UsahaKasDetailPage> {
  List<Map<String, dynamic>> kasList = [];
  final NumberFormat _idrFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isLoadingKas = true;
  StreamSubscription<void>? _remoteChangeSub;

  @override
  void initState() {
    super.initState();
    _loadKas();
    _remoteChangeSub = DatabaseHelper.instance.onRemoteChange.listen((_) async {
      await _loadKas();
    });
  }

  @override
  void dispose() {
    _remoteChangeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadKas() async {
    if (mounted) setState(() => _isLoadingKas = true);
    final data = await DatabaseHelper.instance.getUsahaKasList(widget.folderId);
    if (mounted) {
      setState(() {
        kasList = data;
        _isLoadingKas = false;
      });
    }
  }

  void _showMultiInputUsahaKas() async {
    final _formKey = GlobalKey<FormState>();
    List<TextEditingController> keteranganControllers = [
      TextEditingController()
    ];
    List<TextEditingController> jumlahControllers = [TextEditingController()];
    List<bool> isMasukList = [true];
    DateTime tanggal = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E4),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.playlist_add,
                              color: Color(0xFFF4B41A), size: 28),
                          const SizedBox(width: 10),
                          const Text('Input Kas',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF143D59))),
                          const Spacer(),
                          CircleAvatar(
                            backgroundColor: Colors.red[50],
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.date_range,
                              color: Color(0xFF143D59)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${tanggal.day.toString().padLeft(2, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.year}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_calendar,
                                color: Color(0xFFF4B41A)),
                            label: const Text('Pilih Tanggal'),
                            style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF143D59),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tanggal,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF143D59),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFFFFF5E4),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setStateDialog(() => tanggal = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;
                          final itemWidth = isWide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Wrap(
                              key: ValueKey(keteranganControllers.length),
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(
                                  keteranganControllers.length, (i) {
                                final masuk = isMasukList[i];
                                return SizedBox(
                                  width: itemWidth,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: masuk
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: masuk
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFF44336),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: masuk
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFF44336),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      masuk
                                                          ? Icons.arrow_downward
                                                          : Icons.arrow_upward,
                                                      size: 14,
                                                      color: Colors.white),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      masuk
                                                          ? 'Pemasukan'
                                                          : 'Pengeluaran',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: 'Hapus Baris',
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red),
                                              onPressed: keteranganControllers
                                                          .length >
                                                      1
                                                  ? () {
                                                      setStateDialog(() {
                                                        keteranganControllers
                                                            .removeAt(i);
                                                        jumlahControllers
                                                            .removeAt(i);
                                                        isMasukList.removeAt(i);
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: keteranganControllers[i],
                                          decoration: InputDecoration(
                                            labelText: 'Keterangan',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 10),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Wajib diisi'
                                                  : null,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: jumlahControllers[i],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Jumlah',
                                            prefixText: 'Rp ',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 10),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Wajib diisi'
                                                  : null,
                                          maxLines: 1,
                                          onChanged: (value) {
                                            String digits = value.replaceAll(
                                                RegExp(r'[^0-9]'), '');
                                            if (digits.isEmpty) {
                                              jumlahControllers[i].text = '';
                                              jumlahControllers[i].selection =
                                                  const TextSelection.collapsed(
                                                      offset: 0);
                                              return;
                                            }
                                            final number = int.parse(digits);
                                            final formatted =
                                                NumberFormat.currency(
                                                        locale: 'id_ID',
                                                        symbol: '',
                                                        decimalDigits: 0)
                                                    .format(number)
                                                    .trim();
                                            jumlahControllers[i].text =
                                                formatted;
                                            jumlahControllers[i].selection =
                                                TextSelection.collapsed(
                                                    offset: formatted.length);
                                            setStateDialog(() {});
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ToggleButtons(
                                            isSelected: [masuk, !masuk],
                                            onPressed: (idx) {
                                              setStateDialog(() =>
                                                  isMasukList[i] = idx == 0);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            selectedColor: Colors.white,
                                            fillColor: masuk
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFF44336),
                                            children: const [
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8),
                                                child: Row(children: [
                                                  Icon(Icons.arrow_downward,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Masuk')
                                                ]),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8),
                                                child: Row(children: [
                                                  Icon(Icons.arrow_upward,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Keluar')
                                                ]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF4CAF50)),
                          label: const Text('Tambah Baris'),
                          style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF143D59)),
                          onPressed: () {
                            setStateDialog(() {
                              keteranganControllers
                                  .add(TextEditingController());
                              jumlahControllers.add(TextEditingController());
                              isMasukList.add(true);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon:
                              const Icon(Icons.save, color: Color(0xFF143D59)),
                          label: const Text('Simpan Semua'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF4B41A),
                            foregroundColor: Color(0xFF143D59),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              for (int i = 0;
                                  i < keteranganControllers.length;
                                  i++) {
                                String digits = jumlahControllers[i]
                                    .text
                                    .replaceAll(RegExp(r'[^0-9]'), '');
                                await DatabaseHelper.instance.insertUsahaKas(
                                  folderId: widget.folderId,
                                  tanggal:
                                      '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
                                  keterangan: keteranganControllers[i].text,
                                  nominal: int.tryParse(digits) ?? 0,
                                  tipe: isMasukList[i]
                                      ? 'Pemasukan'
                                      : 'Pengeluaran',
                                );
                              }
                              Navigator.pop(context);
                              await _loadKas();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ringkasan untuk AppBar
    final pemasukan = kasList
        .where((k) => k['tipe'] == 'Pemasukan')
        .fold<int>(0, (a, b) => a + ((b['nominal'] ?? 0) as int));
    final pengeluaran = kasList
        .where((k) => k['tipe'] == 'Pengeluaran')
        .fold<int>(0, (a, b) => a + ((b['nominal'] ?? 0) as int));
    final saldo = pemasukan - pengeluaran;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.25),
        backgroundColor: const Color.fromARGB(0, 216, 208, 208),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: Hero(
          tag: 'folderTitle_${widget.folderId}',
          flightShuttleBuilder: (context, animation, direction, from, to) =>
              FadeTransition(opacity: animation, child: to.widget),
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              widget.folderName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white, // warna putih
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF143D59), Color(0xFF1E4E73)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                left: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Masuk',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _idrFormat.format(pemasukan),
                          key: ValueKey('in_${pemasukan}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Keluar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _idrFormat.format(pengeluaran),
                          key: ValueKey('out_${pengeluaran}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Saldo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _idrFormat.format(saldo),
                          key: ValueKey('bal_${saldo}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5E4), Color(0xFFFFF1D4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
                      .animate(anim),
              child: child,
            ),
          ),
          child: _isLoadingKas
              ? Center(
                  key: const ValueKey('kas_loading'),
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF143D59)),
                    backgroundColor: const Color(0xFF143D59).withOpacity(0.15),
                  ),
                )
              : kasList.isEmpty
                  ? const Center(
                      key: ValueKey('kas_empty'),
                      child: Text('Belum ada data kas.',
                          style: TextStyle(
                              color: Color(0xFFB0A295), fontSize: 18)))
                  : ListView.builder(
                      key: const ValueKey('kas_list'),
                      physics: const BouncingScrollPhysics(),
                      itemCount: kasList.length,
                      itemBuilder: (context, index) {
                        final kas = kasList[index];
                        final isMasuk = kas['tipe'] == 'Pemasukan';
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('kas_${kas['id']}'),
                          duration: Duration(
                              milliseconds: 300 + math.min(index * 35, 350)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, (1 - v) * 12),
                              child: child,
                            ),
                          ),
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            color: isMasuk
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                  horizontal: -1, vertical: -2),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: isMasuk
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                                child: Icon(
                                  isMasuk
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                kas['keterangan'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${kas['tanggal']} | ${kas['tipe']}',
                                    style: const TextStyle(fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _idrFormat.format(kas['nominal']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isMasuk
                                          ? Colors.green[800]
                                          : Colors.red[800],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Color(0xFFF4B41A)),
                                    tooltip: 'Edit',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    splashRadius: 18,
                                    onPressed: () => _showEditKasDialog(kas),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'Hapus',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    splashRadius: 18,
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          backgroundColor:
                                              const Color(0xFFFFF5E4),
                                          title: const Text('Hapus Data Kas',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          content: const Text(
                                              'Yakin ingin menghapus data kas ini?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Hapus',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await DatabaseHelper.instance
                                            .deleteUsahaKas(kas['id']);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Data kas dihapus')),
                                          );
                                        }
                                        _loadKas();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'inputBanyak',
        onPressed: _showMultiInputUsahaKas,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        child: const Icon(Icons.playlist_add),
        tooltip: 'Input Kas Banyak',
      ),
    );
  }

  void _showEditKasDialog(Map<String, dynamic> kas) async {
    final _formKey = GlobalKey<FormState>();
    final keteranganController =
        TextEditingController(text: kas['keterangan'] ?? '');
    final jumlahController =
        TextEditingController(text: kas['nominal']?.toString() ?? '');
    bool isMasuk = kas['tipe'] == 'Pemasukan';
    DateTime tanggal =
        DateTime.tryParse(kas['tanggal'] ?? '') ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF5E4), Color(0xFFFFF1D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                child: StatefulBuilder(
                  builder: (context, setStateDialog) => Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit,
                                  color: Color(0xFFF4B41A), size: 28),
                              const SizedBox(width: 10),
                              const Text('Edit Kas',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF143D59))),
                              const Spacer(),
                              CircleAvatar(
                                backgroundColor: Colors.red[50],
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.date_range,
                                  color: Color(0xFF143D59)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${tanggal.day.toString().padLeft(2, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.year}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_calendar,
                                    color: Color(0xFFF4B41A)),
                                label: const Text('Pilih Tanggal'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Color(0xFF143D59),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tanggal,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF143D59),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFFFFF5E4),
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setStateDialog(() => tanggal = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: keteranganController,
                                  decoration: InputDecoration(
                                    labelText: 'Keterangan',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: jumlahController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Jumlah',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: isMasuk,
                                        activeColor: Color(0xFF4CAF50),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasuk = true),
                                      ),
                                      const Text('Masuk',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: false,
                                        groupValue: isMasuk,
                                        activeColor: Color(0xFFF44336),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasuk = false),
                                      ),
                                      const Text('Keluar',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save,
                                  color: Color(0xFF143D59)),
                              label: const Text('Simpan Perubahan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF4B41A),
                                foregroundColor: Color(0xFF143D59),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  await DatabaseHelper.instance.updateUsahaKas(
                                    id: kas['id'],
                                    tanggal:
                                        '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
                                    keterangan: keteranganController.text,
                                    nominal:
                                        int.tryParse(jumlahController.text) ??
                                            0,
                                    tipe: isMasuk ? 'Pemasukan' : 'Pengeluaran',
                                  );
                                  Navigator.pop(context);
                                  await _loadKas();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
