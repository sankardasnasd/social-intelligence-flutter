import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class GeoColors {
  // ---- existing colors (unchanged) ----
  static const night = Color(0xFF071326);
  static const plum = Color(0xFF10294A);
  static const deep = Color(0xFF17365F);
  static const blue = Color(0xFF2B7FE0);
  static const sky = Color(0xFF4AA3FF);
  static const rain = Color(0xFF7CC4FF);
  static const coral = Color(0xFFFF5D4D);
  static const amber = Color(0xFFF5A524);
  static const green = Color(0xFF22C55E);
  static const field = Color(0xFFF5F9FE);
  static const line = Color(0xFFD7E3F1);

  // ---- new pastel theme ----
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const lineSoft = Color(0xFFDDE3F3);
  static const periwinkle = Color(0xFF5F85FF);
  static const periwinkleDark = Color(0xFF4569E0);
  static const violet = Color(0xFF8F7BFF);
  static const mint = Color(0xFF5FD3B0);
  static const lilac = Color(0xFFB79CFF);
  static const peach = Color(0xFFFFAB91);
  static const sun = Color(0xFFFFD27A);
  static const flag = Color(0xFFFF7A7A);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Social Intelligent',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: GeoColors.bg,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Body font from the web page (Manrope); headings use Outfit
        textTheme: GoogleFonts.manropeTextTheme(),
      ),
      home: DisasterIpPage(),
    );
  }
}

class DisasterIpPage extends StatefulWidget {
  @override
  _DisasterIpPageState createState() => _DisasterIpPageState();
}

class _DisasterIpPageState extends State<DisasterIpPage>
    with TickerProviderStateMixin {
  final _ipController = TextEditingController();
  final _ipFocus = FocusNode();

  late final AnimationController _bgCtrl; // moving background gradient
  late final AnimationController _blobCtrl; // morphing blobs + status cycle
  late final AnimationController _pulseCtrl; // logo rings
  late final AnimationController _shineCtrl; // button shine
  late final AnimationController _floatCtrl; // floating chip
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _states = [
    ['Low risk', 0xFF5FD3B0],
    ['Needs watching', 0xFFFFD27A],
    ['High risk alert', 0xFFFF7A7A],
  ];

  // word swap, same as the hero on the web page
  static const _words = [
    ['safe.', 0xFF5FD3B0],
    ['trending.', 0xFF5F85FF],
    ['loved.', 0xFFFFAB91],
  ];

  TextStyle _outfit(double size, FontWeight w, Color c,
      {double spacing = -0.2}) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: spacing,
    );
  }

  @override
  void initState() {
    super.initState();

    _ipFocus.addListener(() => setState(() {}));

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    final curve = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );

    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ipFocus.dispose();
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _pulseCtrl.dispose();
    _shineCtrl.dispose();
    _floatCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DisasterIpPage(),
          ),
        );

        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // -----------------------------------------
            // SOFT MOVING GRADIENT BACKGROUND
            // -----------------------------------------

            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_bgCtrl.value);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + t * 0.8, -1),
                        end: Alignment(1, 1 - t * 0.8),
                        colors: const [
                          Color(0xFFE7EEFF),
                          Color(0xFFEFE7FF),
                          Color(0xFFDCF6EC),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // -----------------------------------------
            // MORPHING BLOBS
            // -----------------------------------------

            Positioned(
              left: size.width / 2 - 170,
              top: size.height * 0.30 - 170,
              child: IgnorePointer(
                child: _blob(
                  size: 340,
                  colors: const [
                    Color(0xFFC9D8FF),
                    Color(0xFFE0D4FF),
                    Color(0xFFC7F3E3),
                  ],
                  opacity: 1,
                  reverse: false,
                ),
              ),
            ),

            Positioned(
              left: size.width * 0.40,
              top: size.height * 0.62,
              child: IgnorePointer(
                child: _blob(
                  size: 240,
                  colors: const [
                    Color(0xFFFFE0D4),
                    Color(0xFFFFF0C8),
                  ],
                  opacity: 0.8,
                  reverse: true,
                ),
              ),
            ),

            // -----------------------------------------
            // CONFETTI DOTS
            // -----------------------------------------

            _confetti(size.width * 0.12, size.height * 0.08, 14,
                GeoColors.peach, 0.0, 1.0),
            _confetti(size.width * 0.80, size.height * 0.05, 10,
                GeoColors.sun, 0.33, 1.0),
            _confetti(size.width * 0.88, size.height * 0.40, 18,
                GeoColors.lilac, 0.66, 0.7),

            // -----------------------------------------
            // MAIN CONTENT
            // -----------------------------------------

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 30,
                  ),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // -----------------------------------------
                            // FLOATING STATUS CHIP
                            // -----------------------------------------

                            _statusChip(),

                            const SizedBox(height: 18),

                            // -----------------------------------------
                            // TOP LOGO
                            // -----------------------------------------

                            SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (context, _) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          _ring(_pulseCtrl.value),
                                          _ring((_pulseCtrl.value + 0.5) % 1.0),
                                        ],
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 95,
                                    height: 95,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF36498C)
                                              .withOpacity(0.14),
                                          blurRadius: 30,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            GeoColors.periwinkle,
                                            GeoColors.mint,
                                          ],
                                        ),
                                      ),
                                      // shield-check, same as the web logo
                                      child: const Icon(
                                        Icons.verified_user_rounded,
                                        color: Colors.white,
                                        size: 46,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // -----------------------------------------
                            // PROJECT NAME
                            // -----------------------------------------

                            Text(
                              'Social Intelligent',
                              style: _outfit(
                                  32, FontWeight.w700, GeoColors.ink),
                            ),

                            const SizedBox(height: 8),

                            // -----------------------------------------
                            // WORD SWAP: Share reels that are safe / trending / loved
                            // -----------------------------------------

                            _wordSwap(),

                            const SizedBox(height: 26),

                            // -----------------------------------------
                            // CONNECTION CARD
                            // -----------------------------------------

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: GeoColors.lineSoft),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF36498C)
                                        .withOpacity(0.14),
                                    blurRadius: 50,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // -----------------------------------------
                                  // CARD HEADER
                                  // -----------------------------------------

                                  Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFE7EEFF),
                                              Color(0xFFDCF6EC),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.cloud_done_rounded,
                                          color: GeoColors.periwinkleDark,
                                          size: 27,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Connect to Server',
                                              style: _outfit(21,
                                                  FontWeight.w600,
                                                  GeoColors.ink),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Configure the Social Intelligent server',
                                              style: GoogleFonts.manrope(
                                                color: GeoColors.muted,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  // -----------------------------------------
                                  // IP LABEL
                                  // -----------------------------------------

                                  Text(
                                    'Server IP address',
                                    style: GoogleFonts.manrope(
                                      color: GeoColors.ink,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // -----------------------------------------
                                  // IP TEXT FIELD
                                  // -----------------------------------------

                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: _ipFocus.hasFocus
                                          ? [
                                        BoxShadow(
                                          color: GeoColors.periwinkle
                                              .withOpacity(0.18),
                                          spreadRadius: 4,
                                          blurRadius: 0,
                                        ),
                                      ]
                                          : const [],
                                    ),
                                    child: TextField(
                                      controller: _ipController,
                                      focusNode: _ipFocus,
                                      keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                      cursorColor: GeoColors.periwinkle,
                                      style: GoogleFonts.manrope(
                                        color: GeoColors.ink,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Example: 192.168.1.10',
                                        hintStyle: GoogleFonts.manrope(
                                          color: const Color(0xFF9AA4C0),
                                          fontSize: 13.5,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.dns_rounded,
                                          color: GeoColors.periwinkleDark,
                                          size: 21,
                                        ),
                                        filled: true,
                                        fillColor: _ipFocus.hasFocus
                                            ? Colors.white
                                            : GeoColors.bg,
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: GeoColors.lineSoft,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: GeoColors.lineSoft,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: GeoColors.periwinkle,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // -----------------------------------------
                                  // CONNECT BUTTON
                                  // -----------------------------------------

                                  Container(
                                    width: double.infinity,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          GeoColors.periwinkleDark,
                                          GeoColors.violet,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: GeoColors.periwinkle
                                              .withOpacity(0.38),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              senddata();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                              Colors.transparent,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.link_rounded,
                                                  size: 21,
                                                ),
                                                const SizedBox(width: 9),
                                                Text(
                                                  'Connect to Social Intelligent',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 15.5,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // moving shine
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                              child: AnimatedBuilder(
                                                animation: _shineCtrl,
                                                builder: (context, _) {
                                                  final p = ((_shineCtrl.value -
                                                      0.55) /
                                                      0.45)
                                                      .clamp(0.0, 1.0);
                                                  final left = -0.6 + 1.9 * p;
                                                  return Align(
                                                    alignment: Alignment(
                                                        (left / 0.64) * 2 - 1,
                                                        0),
                                                    child: FractionallySizedBox(
                                                      widthFactor: 0.36,
                                                      heightFactor: 1,
                                                      child: Transform(
                                                        transform:
                                                        Matrix4.skewX(
                                                            -0.36),
                                                        child: Container(
                                                          color: Colors.white
                                                              .withOpacity(
                                                              0.35),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // -----------------------------------------
                                  // SECURITY TEXT
                                  // -----------------------------------------

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 14,
                                        color: Color(0xFF1F7A5C),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Secure server connection',
                                        style: GoogleFonts.manrope(
                                          color: GeoColors.muted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // -----------------------------------------
                            // FACTS ROW (pulsing mint dots, like the web hero)
                            // -----------------------------------------

                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 22,
                              runSpacing: 8,
                              children: [
                                _fact('Video, audio and image'),
                                _fact('Safety check on every upload'),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // -----------------------------------------
                            // COPYRIGHT
                            // -----------------------------------------

                            Text(
                              '© 2026 Social Intelligent',
                              style: GoogleFonts.manrope(
                                color: GeoColors.muted,
                                fontSize: 10.5,
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
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DECORATION HELPERS
  // =========================================================

  // "Share reels that are" + swapping word (safe. / trending. / loved.)
  Widget _wordSwap() {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) {
        final index = (_blobCtrl.value * 12).floor() % 3;
        final word = _words[index][0] as String;
        final color = Color(_words[index][1] as int);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Share reels that are ',
              style: _outfit(17, FontWeight.w500, GeoColors.muted,
                  spacing: 0),
            ),
            SizedBox(
              height: 26,
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final isIncoming = child.key == ValueKey(word);
                    final offset = Tween<Offset>(
                      begin: isIncoming
                          ? const Offset(0, 1)
                          : const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(anim);
                    return SlideTransition(
                      position: offset,
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: Text(
                    word,
                    key: ValueKey(word),
                    style: _outfit(17, FontWeight.w700, color, spacing: 0),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fact(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, _) {
            final s = 1 + 0.5 * Curves.easeInOut.transform(_floatCtrl.value);
            return Transform.scale(
              scale: s,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GeoColors.mint
                      .withOpacity(1 - 0.4 * _floatCtrl.value),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.manrope(
            color: GeoColors.muted,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _ring(double t) {
    return Container(
      width: 95 + 35 * t,
      height: 95 + 35 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: GeoColors.mint.withOpacity((1 - t) * 0.8),
          width: 2,
        ),
      ),
    );
  }

  BorderRadius _morph(double t, double s) {
    double l(double a, double b) => (a + (b - a) * t) * s;
    return BorderRadius.only(
      topLeft: Radius.elliptical(l(0.60, 0.40), l(0.50, 0.60)),
      topRight: Radius.elliptical(l(0.40, 0.60), l(0.60, 0.40)),
      bottomRight: Radius.elliptical(l(0.55, 0.45), l(0.40, 0.60)),
      bottomLeft: Radius.elliptical(l(0.45, 0.55), l(0.50, 0.40)),
    );
  }

  Widget _blob({
    required double size,
    required List<Color> colors,
    required double opacity,
    required bool reverse,
  }) {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) {
        final v = _blobCtrl.value;
        final m = (math.sin(v * 2 * math.pi * 3) + 1) / 2;
        final angle = (reverse ? -1 : 1) * v * 2 * math.pi;

        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: _morph(m, size),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _confetti(double left, double top, double d, Color color,
      double phase, double opacity) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, _) {
            final t =
            Curves.easeInOut.transform((_floatCtrl.value + phase) % 1.0);
            return Transform.translate(
              offset: Offset(16 * t, -24 * t),
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(opacity),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Cycles safe / watch / alert, like the scan result on the web page
  Widget _statusChip() {
    return AnimatedBuilder(
      animation: Listenable.merge([_blobCtrl, _floatCtrl]),
      builder: (context, _) {
        final index = (_blobCtrl.value * 9).floor() % 3;
        final label = _states[index][0] as String;
        final color = Color(_states[index][1] as int);

        return Transform.translate(
          offset: Offset(0, -8 * Curves.easeInOut.transform(_floatCtrl.value)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GeoColors.lineSoft),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF36498C).withOpacity(0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: GeoColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // SEND DATA (unchanged)
  // =========================================================

  void senddata() async {
    String ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter the server IP address',
            style: TextStyle(color: Color(0xFFA63B3B)),
          ),
          backgroundColor: const Color(0xFFFFF0F0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFFC9C9)),
          ),
        ),
      );

      return;
    }

    print(ip);

    SharedPreferences sh = await SharedPreferences.getInstance();

    // -----------------------------------------
    // SERVER SETTINGS
    // -----------------------------------------

    await sh.setString('ip', ip);
    await sh.setString('url', 'http://$ip:8000');
    await sh.setString('imgurl', 'http://$ip:8000/');
    await sh.setString('imgurl2', 'http://$ip:8000/');

    // -----------------------------------------
    // GO TO LOGIN
    // -----------------------------------------

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ),
    );
  }
}