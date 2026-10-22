import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
// CHANGE PASSWORD PAGE
// ============================================================

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  String _error = '';
  bool _success = false;

  // ---------------- ANIMATION ----------------
  late final AnimationController _bgCtrl;
  late final AnimationController _blobCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shineCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    final curve = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    // live strength meter + clear old error while typing
    newController.addListener(_onTyping);
    confirmController.addListener(_onTyping);
    oldController.addListener(() {
      if (_error.isNotEmpty && mounted) setState(() => _error = '');
    });
  }

  void _onTyping() {
    if (!mounted) return;
    setState(() {
      _error = '';
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    oldController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHANGE PASSWORD API
  // ============================================================

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = '';
    });

    try {
      final sh = await SharedPreferences.getInstance();

      final lid = sh.getString('lid') ?? '';
      String baseUrl = sh.getString('url') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        _setError('Server URL not configured');
        return;
      }

      if (lid.isEmpty) {
        _setError('Login ID not found. Please sign in again');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_change_password/');

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'old_password': oldController.text,
          'new_password': newController.text,
          'confirm_password': confirmController.text,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Change password status: ${response.statusCode}');
      debugPrint('Change password response: ${response.body}');

      Map<String, dynamic>? result;
      try {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        result = null;
      }

      if (result == null) {
        _setError('Server error: ${response.statusCode}');
        return;
      }

      if (result['status'] == 'ok' && response.statusCode == 200) {
        if (!mounted) return;

        oldController.clear();
        newController.clear();
        confirmController.clear();
        _formKey.currentState?.reset();

        setState(() {
          _success = true;
          _error = '';
        });

        _showMessage(
          result['message']?.toString() ?? 'Password changed successfully',
        );

        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) Navigator.maybePop(context);
        return;
      }

      // server returns message as a string or a list of strings
      final dynamic m = result['message'];
      if (m is List) {
        _setError(m.map((e) => e.toString()).join('\n'));
      } else {
        _setError(m?.toString() ?? 'Unable to change password');
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      _setError('Unable to connect. Check the server and try again');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(color: _C.ink)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _C.line),
        ),
      ),
    );
  }

  // ============================================================
  // STRENGTH (client side hint only, the server does final checks)
  // ============================================================

  bool get _hasLen => newController.text.length >= 8;
  bool get _hasMix =>
      RegExp(r'[a-z]').hasMatch(newController.text) &&
          RegExp(r'[A-Z]').hasMatch(newController.text);
  bool get _hasNum => RegExp(r'[0-9]').hasMatch(newController.text);
  bool get _hasSym => RegExp(r'[^A-Za-z0-9]').hasMatch(newController.text);
  bool get _matches =>
      confirmController.text.isNotEmpty &&
          confirmController.text == newController.text;

  int get _score {
    if (newController.text.isEmpty) return 0;
    int s = 0;
    if (_hasLen) s++;
    if (_hasMix) s++;
    if (_hasNum) s++;
    if (_hasSym) s++;
    return s;
  }

  // ============================================================
  // DESIGN HELPERS
  // ============================================================

  TextStyle _outfit(double size, FontWeight w, Color c,
      {double spacing = -0.2}) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: spacing,
    );
  }

  Widget _passField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        cursorColor: _C.blue,
        style: GoogleFonts.manrope(color: _C.ink, fontSize: 15),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: _C.muted, fontSize: 13.5),
          floatingLabelStyle: GoogleFonts.manrope(
            color: _C.blueDark,
            fontWeight: FontWeight.w700,
          ),
          errorStyle: GoogleFonts.manrope(
            color: const Color(0xFFD84B4B),
            fontSize: 11.5,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: _C.blueDark,
            size: 21,
          ),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _C.muted,
            ),
          ),
          filled: true,
          fillColor: _C.bg,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderSide: const BorderSide(color: _C.blue, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.flag, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.flag, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _strengthMeter() {
    final s = _score;
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [_C.line, _C.flag, _C.sun, _C.blue, _C.mint];
    final color = colors[s];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < s ? color : _C.line,
                    ),
                  ),
                ),
                if (i != 3) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s == 0 ? 'Password strength' : labels[s],
            style: GoogleFonts.manrope(
              color: s == 0 ? _C.muted : color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? _C.mint : _C.line,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: ok ? Colors.white : Colors.transparent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: ok ? _C.ink : _C.muted,
                fontSize: 12.5,
                fontWeight: ok ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _error.isEmpty
          ? const SizedBox(width: double.infinity)
          : Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFC9C9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD84B4B),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error,
                style: GoogleFonts.manrope(
                  color: const Color(0xFFA63B3B),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
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

  Widget _ring(double t) {
    return Container(
      width: 88 + 32 * t,
      height: 88 + 32 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _C.mint.withOpacity((1 - t) * 0.8),
          width: 2,
        ),
      ),
    );
  }

  Widget _logo() {
    return SizedBox(
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
                  _ring((_pulseCtrl.value + 0.5) % 1.0),
                ],
              );
            },
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _C.shadow.withOpacity(0.16),
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
              child: Icon(
                _success ? Icons.check_rounded : Icons.key_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return Opacity(
      opacity: _isSubmitting ? 0.7 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_C.blueDark, _C.violet],
          ),
          boxShadow: [
            BoxShadow(
              color: _C.blue.withOpacity(0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_rounded, size: 20),
                    const SizedBox(width: 9),
                    Text(
                      'Update password',
                      style: GoogleFonts.manrope(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedBuilder(
                    animation: _shineCtrl,
                    builder: (context, _) {
                      final p =
                      ((_shineCtrl.value - 0.55) / 0.45).clamp(0.0, 1.0);
                      final left = -0.6 + 1.9 * p;
                      return Align(
                        alignment: Alignment((left / 0.64) * 2 - 1, 0),
                        child: FractionallySizedBox(
                          widthFactor: 0.36,
                          heightFactor: 1,
                          child: Transform(
                            transform: Matrix4.skewX(-0.36),
                            child: Container(
                              color: Colors.white.withOpacity(0.35),
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
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
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
          Positioned(
            left: size.width / 2 - 170,
            top: size.height * 0.16 - 170,
            child: IgnorePointer(
              child: _blob(
                size: 340,
                colors: const [
                  Color(0xFFC9D8FF),
                  Color(0xFFE0D4FF),
                  Color(0xFFC7F3E3),
                ],
                opacity: 0.9,
                reverse: false,
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.45,
            top: size.height * 0.70,
            child: IgnorePointer(
              child: _blob(
                size: 240,
                colors: const [Color(0xFFFFE0D4), Color(0xFFFFF0C8)],
                opacity: 0.7,
                reverse: true,
              ),
            ),
          ),
          _confetti(size.width * 0.10, size.height * 0.16, 14, _C.peach, 0.0, 1.0),
          _confetti(size.width * 0.84, size.height * 0.10, 10, _C.sun, 0.33, 1.0),
          _confetti(size.width * 0.92, size.height * 0.52, 18, _C.lilac, 0.66, 0.7),
          SafeArea(
            child: Column(
              children: [
                // ---------------- TOP BAR ----------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withOpacity(0.92),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _C.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.maybePop(context),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: _C.ink,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Change Password',
                          textAlign: TextAlign.center,
                          style: _outfit(20, FontWeight.w600, _C.ink),
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding:
                            const EdgeInsets.fromLTRB(20, 10, 20, 30),
                            children: [
                              Center(child: _logo()),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  _success
                                      ? 'Password updated'
                                      : 'Keep your account safe',
                                  style: _outfit(24, FontWeight.w700, _C.ink),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Enter your current password, then choose a new one',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: _C.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),

                              // ---------------- CARD ----------------
                              Container(
                                padding: const EdgeInsets.all(24),
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
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _errorBanner(),

                                      _passField(
                                        label: 'Current password',
                                        controller: oldController,
                                        obscure: _obscureOld,
                                        onToggle: () => setState(
                                                () => _obscureOld = !_obscureOld),
                                        validator: (v) =>
                                        v == null || v.isEmpty
                                            ? 'Enter current password'
                                            : null,
                                      ),

                                      const Divider(height: 26, color: _C.line),

                                      _passField(
                                        label: 'New password',
                                        controller: newController,
                                        obscure: _obscureNew,
                                        onToggle: () => setState(
                                                () => _obscureNew = !_obscureNew),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Enter new password';
                                          }
                                          if (v.length < 8) {
                                            return 'Password must contain at least 8 characters';
                                          }
                                          if (v == oldController.text) {
                                            return 'New password must be different';
                                          }
                                          return null;
                                        },
                                      ),

                                      _strengthMeter(),

                                      _rule('At least 8 characters', _hasLen),
                                      _rule('Upper and lower case letters',
                                          _hasMix),
                                      _rule('Includes a number', _hasNum),
                                      _rule('Includes a symbol', _hasSym),

                                      const SizedBox(height: 20),

                                      _passField(
                                        label: 'Confirm new password',
                                        controller: confirmController,
                                        obscure: _obscureConfirm,
                                        action: TextInputAction.done,
                                        onSubmitted: (_) => _changePassword(),
                                        onToggle: () => setState(() =>
                                        _obscureConfirm =
                                        !_obscureConfirm),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Confirm new password';
                                          }
                                          if (v != newController.text) {
                                            return 'New passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),

                                      _rule('Both passwords match', _matches),

                                      const SizedBox(height: 22),

                                      _submitButton(),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

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
                                    'Your password is sent securely',
                                    style: GoogleFonts.manrope(
                                      color: _C.muted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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