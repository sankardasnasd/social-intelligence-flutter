import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:social_intelligent/user%20register.dart';

import 'user/home.dart';

// ============================================================
// COLORS  (soft pastel theme)
// ============================================================

class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const blueDark = Color(0xFF4569E0);
  static const violet = Color(0xFF8F7BFF);
  static const mint = Color(0xFF5FD3B0);
  static const lilac = Color(0xFFB79CFF);
  static const peach = Color(0xFFFFAB91);
  static const sun = Color(0xFFFFD27A);
  static const flag = Color(0xFFFF7A7A);
  static const shadow = Color(0xFF36498C);
}

// ============================================================
// MAIN
// ============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ============================================================
// APP
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Intelligent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: _C.blue,
        scaffoldBackgroundColor: _C.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _C.blue,
          primary: _C.blue,
          secondary: _C.mint,
        ),
        textTheme: GoogleFonts.manropeTextTheme(),
        inputDecorationTheme: const InputDecorationTheme(
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  // ==========================================================
  // LOGIN VARIABLES
  // ==========================================================

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _bgCtrl; // moving gradient
  late final AnimationController _blobCtrl; // blobs, status, word swap
  late final AnimationController _pulseCtrl; // logo rings
  late final AnimationController _shineCtrl; // button shine
  late final AnimationController _floatCtrl; // floating chips
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _states = [
    ['Safe to publish', 0xFF5FD3B0],
    ['Needs review', 0xFFFFD27A],
    ['Flagged', 0xFFFF7A7A],
  ];

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

  // ==========================================================
  // INIT STATE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _userFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));

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

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _pulseCtrl.dispose();
    _shineCtrl.dispose();
    _floatCtrl.dispose();
    _enterCtrl.dispose();

    _usernameController.dispose();
    _passwordController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();

    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        bool exit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              "Exit App",
              style: _outfit(20, FontWeight.w600, _C.ink),
            ),
            content: Text(
              "Are you sure you want to exit Social Intelligent?",
              style: GoogleFonts.manrope(color: _C.muted),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  "Cancel",
                  style: GoogleFonts.manrope(
                    color: _C.blueDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.flag,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Exit"),
              ),
            ],
          ),
        ) ??
            false;

        return exit;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ----------------------------------------------
            // SOFT MOVING GRADIENT
            // ----------------------------------------------

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

            // ----------------------------------------------
            // MORPHING BLOBS
            // ----------------------------------------------

            Positioned(
              left: size.width / 2 - 190,
              top: size.height * 0.22 - 190,
              child: IgnorePointer(
                child: _blob(
                  size: 380,
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
              left: size.width * 0.38,
              top: size.height * 0.66,
              child: IgnorePointer(
                child: _blob(
                  size: 260,
                  colors: const [
                    Color(0xFFFFE0D4),
                    Color(0xFFFFF0C8),
                  ],
                  opacity: 0.8,
                  reverse: true,
                ),
              ),
            ),

            // ----------------------------------------------
            // CONFETTI DOTS
            // ----------------------------------------------

            _confetti(size.width * 0.10, size.height * 0.10, 14, _C.peach,
                0.0, 1.0),
            _confetti(size.width * 0.82, size.height * 0.07, 10, _C.sun,
                0.33, 1.0),
            _confetti(size.width * 0.90, size.height * 0.45, 18, _C.lilac,
                0.66, 0.7),
            _confetti(size.width * 0.06, size.height * 0.72, 12, _C.mint,
                0.5, 0.9),

            // ----------------------------------------------
            // CONTENT
            // ----------------------------------------------

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 26,
                    ),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 470),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ================================
                                // STATUS CHIP
                                // ================================

                                _statusChip(),

                                const SizedBox(height: 16),

                                // ================================
                                // LOGO
                                // ================================

                                SizedBox(
                                  width: 124,
                                  height: 124,
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
                                              _ring((_pulseCtrl.value + 0.5) %
                                                  1.0),
                                            ],
                                          );
                                        },
                                      ),
                                      Container(
                                        width: 92,
                                        height: 92,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _C.shadow
                                                  .withOpacity(0.16),
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
                                              colors: [_C.blue, _C.mint],
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.verified_user_rounded,
                                            color: Colors.white,
                                            size: 44,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  "Social Intelligent",
                                  style: _outfit(
                                      32, FontWeight.w700, _C.ink),
                                ),

                                const SizedBox(height: 8),

                                _wordSwap(),

                                const SizedBox(height: 16),

                                // ================================
                                // FLOATING MINI CHIPS
                                // ================================

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _miniChip(Icons.trending_up_rounded,
                                        "Trend score 87", _C.blue, 0.0),
                                    const SizedBox(width: 12),
                                    _miniChip(Icons.bolt_rounded,
                                        "Reach 12.4K", _C.peach, 0.5),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // ================================
                                // LOGIN CARD
                                // ================================

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: _C.line),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _C.shadow.withOpacity(0.14),
                                        blurRadius: 50,
                                        offset: const Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          "Welcome Back",
                                          style: _outfit(
                                              26, FontWeight.w700, _C.ink),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Center(
                                        child: Text(
                                          "Sign in to continue to Social Intelligent",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13.5,
                                            color: _C.muted,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 26),

                                      // ---------------- USERNAME ----------------

                                      _fieldLabel("Username"),
                                      const SizedBox(height: 8),

                                      _glowField(
                                        focus: _userFocus,
                                        child: TextField(
                                          controller: _usernameController,
                                          focusNode: _userFocus,
                                          keyboardType: TextInputType.text,
                                          textInputAction:
                                          TextInputAction.next,
                                          cursorColor: _C.blue,
                                          style: GoogleFonts.manrope(
                                            color: _C.ink,
                                            fontSize: 15,
                                          ),
                                          decoration: _inputDecoration(
                                            label: "Enter your username",
                                            icon:
                                            Icons.person_outline_rounded,
                                            focus: _userFocus,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // ---------------- PASSWORD ----------------

                                      _fieldLabel("Password"),
                                      const SizedBox(height: 8),

                                      _glowField(
                                        focus: _passFocus,
                                        child: TextField(
                                          controller: _passwordController,
                                          focusNode: _passFocus,
                                          obscureText: _obscurePassword,
                                          textInputAction:
                                          TextInputAction.done,
                                          cursorColor: _C.blue,
                                          style: GoogleFonts.manrope(
                                            color: _C.ink,
                                            fontSize: 15,
                                          ),
                                          onSubmitted: (_) {
                                            senddata();
                                          },
                                          decoration: _inputDecoration(
                                            label: "Enter your password",
                                            icon: Icons.lock_outline_rounded,
                                            focus: _passFocus,
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                  !_obscurePassword;
                                                });
                                              },
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                    .visibility_off_outlined
                                                    : Icons
                                                    .visibility_outlined,
                                                color: _C.muted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // ---------------- LOGIN BUTTON ----------------

                                      Opacity(
                                        opacity: _isLoading ? 0.7 : 1,
                                        child: Container(
                                          width: double.infinity,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                            gradient: const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                _C.blueDark,
                                                _C.violet
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                _C.blue.withOpacity(.38),
                                                blurRadius: 24,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ElevatedButton(
                                                  onPressed: _isLoading
                                                      ? null
                                                      : senddata,
                                                  style: ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                    Colors.transparent,
                                                    disabledBackgroundColor:
                                                    Colors.transparent,
                                                    foregroundColor:
                                                    Colors.white,
                                                    disabledForegroundColor:
                                                    Colors.white,
                                                    elevation: 0,
                                                    shadowColor:
                                                    Colors.transparent,
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(14),
                                                    ),
                                                  ),
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                    width: 23,
                                                    height: 23,
                                                    child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color:
                                                      Colors.white,
                                                    ),
                                                  )
                                                      : Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .login_rounded,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(
                                                          width: 9),
                                                      Text(
                                                        "Sign in",
                                                        style: GoogleFonts
                                                            .manrope(
                                                          fontSize: 15.5,
                                                          fontWeight:
                                                          FontWeight
                                                              .w700,
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
                                                    BorderRadius.circular(
                                                        14),
                                                    child: AnimatedBuilder(
                                                      animation: _shineCtrl,
                                                      builder: (context, _) {
                                                        final p = ((_shineCtrl
                                                            .value -
                                                            0.55) /
                                                            0.45)
                                                            .clamp(0.0, 1.0);
                                                        final left =
                                                            -0.6 + 1.9 * p;
                                                        return Align(
                                                          alignment: Alignment(
                                                              (left / 0.64) *
                                                                  2 -
                                                                  1,
                                                              0),
                                                          child:
                                                          FractionallySizedBox(
                                                            widthFactor: 0.36,
                                                            heightFactor: 1,
                                                            child: Transform(
                                                              transform:
                                                              Matrix4
                                                                  .skewX(
                                                                  -0.36),
                                                              child:
                                                              Container(
                                                                color: Colors
                                                                    .white
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
                                      ),

                                      const SizedBox(height: 22),

                                      // ---------------- DIVIDER ----------------

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: _C.line,
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              "OR",
                                              style: GoogleFonts.manrope(
                                                color:
                                                const Color(0xFF9AA4C0),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: _C.line,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      // ---------------- USER REGISTER ----------------

                                      _actionTile(
                                        icon: Icons.person_add_alt_1_rounded,
                                        text: "Don't have an account?",
                                        button: "Register",
                                        accent: _C.blueDark,
                                        background: _C.bg,
                                        border: _C.line,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  UserRegisterPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ================================
                                // FACTS ROW
                                // ================================

                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 22,
                                  runSpacing: 8,
                                  children: [
                                    _fact("Video, audio and image"),
                                    _fact("Safety check on every upload"),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  "© 2026 Social Intelligent",
                                  style: GoogleFonts.manrope(
                                    color: _C.muted,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: _C.ink,
      ),
    );
  }

  // soft focus glow around a field
  Widget _glowField({required FocusNode focus, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: focus.hasFocus
            ? [
          BoxShadow(
            color: _C.blue.withOpacity(0.18),
            spreadRadius: 4,
            blurRadius: 0,
          ),
        ]
            : const [],
      ),
      child: child,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String text,
    required String button,
    required Color accent,
    required Color background,
    required Color border,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE7EEFF), Color(0xFFDCF6EC)],
              ),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(fontSize: 12.5, color: _C.muted),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: accent.withOpacity(0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              button,
              style: GoogleFonts.manrope(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double t) {
    return Container(
      width: 92 + 32 * t,
      height: 92 + 32 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _C.mint.withOpacity((1 - t) * 0.8),
          width: 2,
        ),
      ),
    );
  }

  // "Share reels that are" + swapping word
  Widget _wordSwap() {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) {
        final index = (_blobCtrl.value * 12).floor() % 3;
        final word = _words[index][0] as String;
        final color = Color(_words[index][1] as int);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Share reels that are ',
              style: _outfit(17, FontWeight.w500, _C.muted, spacing: 0),
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

  // glassy floating chip with icon
  Widget _miniChip(IconData icon, String text, Color accent, double phase) {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform((_floatCtrl.value + phase) % 1.0);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: _C.shadow.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.ink,
                  ),
                ),
              ],
            ),
          ),
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
                  color: _C.mint.withOpacity(1 - 0.4 * _floatCtrl.value),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.manrope(color: _C.muted, fontSize: 12.5),
        ),
      ],
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

  // Cycles safe / review / flagged like the scan result on the web page
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
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: _C.shadow.withOpacity(0.14),
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
                    color: _C.ink,
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

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required FocusNode focus,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: label,
      hintStyle: GoogleFonts.manrope(
        color: const Color(0xFF9AA4C0),
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, color: _C.blueDark, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: focus.hasFocus ? Colors.white : _C.bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.blue, width: 1.5),
      ),
    );
  }

  // ============================================================
  // LOGIN API  (unchanged)
  // ============================================================

  Future<void> senddata() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (username.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter username",
      );
      return;
    }

    if (password.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter password",
      );
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences sh = await SharedPreferences.getInstance();

      String? baseUrl = sh.getString("url");

      if (baseUrl == null || baseUrl.isEmpty || baseUrl == "null") {
        Fluttertoast.showToast(
          msg: "Server URL not configured",
        );
        return;
      }

      // Remove trailing /
      baseUrl = baseUrl.replaceFirst(
        RegExp(r'/$'),
        '',
      );

      final Uri url = Uri.parse(
        "$baseUrl/myapp/app_login/",
      );

      debugPrint("Login URL: $url");

      // --------------------------------------------------------
      // LOGIN REQUEST
      // --------------------------------------------------------

      final response = await http.post(
        url,
        body: {
          "username": username,
          "password": password,
        },
      ).timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        "Login status: ${response.statusCode}",
      );

      debugPrint(
        "Login response: ${response.body}",
      );

      // --------------------------------------------------------
      // SERVER RESPONSE CHECK
      // --------------------------------------------------------

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
          msg: "Server error: ${response.statusCode}",
        );
        return;
      }

      final responseData = jsonDecode(
        response.body,
      );

      String status = responseData["status"]?.toString() ?? "";

      // ========================================================
      // PENDING VOLUNTEER
      // ========================================================

      if (status == "not") {
        Fluttertoast.showToast(
          msg: responseData["message"]?.toString() ??
              "Waiting For Admin Approval",
        );
        return;
      }

      // ========================================================
      // REJECTED
      // ========================================================

      if (status == "rejected") {
        Fluttertoast.showToast(
          msg: responseData["message"]?.toString() ??
              "Your application was rejected",
        );
        return;
      }

      // ========================================================
      // INVALID LOGIN
      // ========================================================

      if (status == "no") {
        Fluttertoast.showToast(
          msg: responseData["message"]?.toString() ??
              "Invalid username or password",
        );
        return;
      }

      // ========================================================
      // OTHER ERROR
      // ========================================================

      if (status != "ok") {
        Fluttertoast.showToast(
          msg: responseData["message"]?.toString() ?? "Login failed",
        );
        return;
      }

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      String type = responseData["type"]?.toString() ?? "";

      String lid = responseData["lid"]?.toString() ?? "";

      if (lid.isEmpty) {
        Fluttertoast.showToast(
          msg: "Login ID not received",
        );
        return;
      }

      // Save login ID
      await sh.setString(
        "lid",
        lid,
      );

      await sh.setString(
        "ShakeAlert",
        "ok",
      );

      Fluttertoast.showToast(
        msg: "Login Successful",
      );

      // ========================================================
      // USER
      // ========================================================

      if (type == "User") {
        // Track the logged-in user's location only while the app is in foreground.
        await Social_intelligent.instance.start(lid);

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Unrecognized user type",
        );
      }
    }

    // ----------------------------------------------------------
    // TIMEOUT
    // ----------------------------------------------------------

    on TimeoutException {
      Fluttertoast.showToast(
        msg: "Server connection timeout",
      );
    }

    // ----------------------------------------------------------
    // INVALID JSON
    // ----------------------------------------------------------

    on FormatException {
      Fluttertoast.showToast(
        msg: "Invalid server response",
      );
    }

    // ----------------------------------------------------------
    // OTHER ERROR
    // ----------------------------------------------------------

    catch (e) {
      Fluttertoast.showToast(
        msg: "Connection Error",
      );

      debugPrint(
        "Login Error: $e",
      );
    }

    // ----------------------------------------------------------
    // LOADING COMPLETE
    // ----------------------------------------------------------

    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// ============================================================
// LOCATION TRACKER  (unchanged)
// ============================================================

class Social_intelligent with WidgetsBindingObserver {
  Social_intelligent._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final Social_intelligent instance = Social_intelligent._internal();

  final Location _location = Location();

  Timer? _timer;
  String? _loginId;
  bool _trackingEnabled = false;
  bool _requestInProgress = false;

  static const Duration _updateInterval = Duration(seconds: 30);

  Future<void> start(String lid) async {
    if (lid.trim().isEmpty) {
      debugPrint('Location tracking not started: empty login ID');
      return;
    }

    _loginId = lid;
    _trackingEnabled = true;

    // Request permission only after successful login.
    final bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      final bool enabled = await _location.requestService();
      if (!enabled) {
        debugPrint('Location service is disabled');
        return;
      }
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    if (permission != PermissionStatus.granted) {
      debugPrint('Location permission was not granted');
      return;
    }

    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _startForegroundTimer();
    }
  }

  void _startForegroundTimer() {
    if (!_trackingEnabled || _loginId == null) return;

    _timer?.cancel();

    // Send the current location immediately.
    _updateLocation();

    // Then update every 30 seconds.
    _timer = Timer.periodic(_updateInterval, (_) {
      _updateLocation();
    });
  }

  void stop() {
    _trackingEnabled = false;
    _timer?.cancel();
    _timer = null;
    _loginId = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_trackingEnabled) return;

    if (state == AppLifecycleState.resumed) {
      _startForegroundTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _updateLocation() async {
    final String? lid = _loginId;
    if (!_trackingEnabled || lid == null || _requestInProgress) return;

    _requestInProgress = true;

    try {
      final LocationData current = await _location.getLocation();
      final double? latitude = current.latitude;
      final double? longitude = current.longitude;

      if (latitude == null || longitude == null) {
        debugPrint('Location tracker: GPS coordinates unavailable');
        return;
      }

      final String lat = latitude.toString();
      final String lon = longitude.toString();

      final SharedPreferences sh = await SharedPreferences.getInstance();
      await sh.setString('lat', lat);
      await sh.setString('lon', lon);

      String baseUrl = sh.getString('url') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        debugPrint('Location tracker: Django base URL is not configured');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/updatelocation/');

      final http.Response response = await http.post(
        url,
        body: {
          'lid': lid,
          'lat': lat,
          'lon': lon,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint(
        'Social Intelligent location update: ${response.statusCode} ${response.body}',
      );

      if (response.statusCode == 200) {
        try {
          final dynamic data = jsonDecode(response.body);
          if (data is Map && data['status'] == 'ok') {
            debugPrint('Social Intelligent location saved successfully');
          } else {
            debugPrint('Django did not confirm the location update');
          }
        } on FormatException {
          debugPrint('Location endpoint returned invalid JSON');
        }
      }
    } catch (e) {
      debugPrint('Social Intelligent location update error: $e');
    } finally {
      _requestInProgress = false;
    }
  }
}