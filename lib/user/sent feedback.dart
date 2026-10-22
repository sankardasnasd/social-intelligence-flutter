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
  static const star = Color(0xFFFFB933);
  static const flag = Color(0xFFFF7A7A);
  static const shadow = Color(0xFF36498C);
}

// ============================================================
// FEEDBACK PAGE
// ============================================================

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final feedbackController = TextEditingController();
  final feedbackFocus = FocusNode();

  int _rating = 0;
  bool _ratingError = false;
  bool _isSubmitting = false;
  bool _sent = false;

  static const _labels = [
    '',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  static const _hints = [
    'Tap a star to rate your experience',
    'We are sorry. Tell us what went wrong',
    'Not great. How can we improve?',
    'Thanks. What could be better?',
    'Glad you liked it. Tell us more',
    'Wonderful. What did you love?',
  ];

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

    feedbackFocus.addListener(() {
      if (mounted) setState(() {});
    });
    feedbackController.addListener(() {
      if (mounted) setState(() {});
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
    feedbackController.dispose();
    feedbackFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND FEEDBACK API
  // ============================================================

  Future<void> _sendFeedback() async {
    FocusScope.of(context).unfocus();

    final textOk = _formKey.currentState!.validate();

    if (_rating == 0) {
      setState(() {
        _ratingError = true;
      });
    }

    if (!textOk || _rating == 0) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final sh = await SharedPreferences.getInstance();

      final lid = sh.getString('lid') ?? '';
      String baseUrl = sh.getString('url') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        _showMessage('Server URL not configured');
        return;
      }

      if (lid.isEmpty) {
        _showMessage('Login ID not found. Please sign in again');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_send_feedback/');

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'feedback_text': feedbackController.text.trim(),
          'rating': _rating.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Feedback status: ${response.statusCode}');
      debugPrint('Feedback response: ${response.body}');

      if (response.statusCode != 200) {
        _showMessage('Server error: ${response.statusCode}');
        return;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['status'] == 'ok') {
        if (!mounted) return;

        setState(() {
          _sent = true;
        });

        _showMessage('Thank you for your feedback');

        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.maybePop(context);
      } else {
        _showMessage(
          result['message']?.toString() ?? 'Unable to send feedback',
        );
      }
    } catch (e) {
      debugPrint('Feedback error: $e');
      _showMessage('Unable to connect. Check the server and try again');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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

  Color get _ratingColor {
    switch (_rating) {
      case 1:
        return _C.flag;
      case 2:
        return _C.peach;
      case 3:
        return _C.sun;
      case 4:
        return _C.blue;
      case 5:
        return _C.mint;
      default:
        return _C.muted;
    }
  }

  void _setRating(int value) {
    if (value < 1 || value > 5 || value == _rating) return;
    setState(() {
      _rating = value;
      _ratingError = false;
    });
  }

  // star row: tap or drag across the stars
  Widget _stars() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        void fromDx(double dx) {
          final index = (dx / (w / 5)).floor() + 1;
          _setRating(index.clamp(1, 5));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => fromDx(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => fromDx(d.localPosition.dx),
          child: Row(
            children: List.generate(5, (i) {
              final filled = i < _rating;
              final current = i == _rating - 1;

              return Expanded(
                child: AnimatedScale(
                  scale: current ? 1.28 : (filled ? 1.0 : 0.92),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.elasticOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey('$i-$filled'),
                      size: 48,
                      color: filled
                          ? _C.star
                          : (_ratingError
                          ? _C.flag.withOpacity(0.7)
                          : const Color(0xFFC3CBE4)),
                      shadows: filled
                          ? [
                        Shadow(
                          color: _C.star.withOpacity(0.45),
                          blurRadius: 14,
                        ),
                      ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _ratingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _ratingError ? _C.flag : _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF0C8), Color(0xFFFFE0D4)],
                  ),
                ),
                child: const Icon(Icons.star_rounded,
                    color: _C.star, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your rating',
                        style: _outfit(18, FontWeight.w600, _C.ink)),
                    const SizedBox(height: 2),
                    Text(
                      'How was your experience?',
                      style: GoogleFonts.manrope(color: _C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _ratingColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _rating == 0 ? '0 / 5' : '$_rating / 5',
                  style: GoogleFonts.outfit(
                    color: _rating == 0 ? _C.muted : _C.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _stars(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _rating == 0 ? 'Rate us' : _labels[_rating],
              key: ValueKey(_rating),
              style: _outfit(
                22,
                FontWeight.w700,
                _rating == 0 ? _C.muted : _ratingColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ratingError ? 'Please select a rating' : _hints[_rating],
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _ratingError ? const Color(0xFFD84B4B) : _C.muted,
              fontSize: 12.5,
              fontWeight: _ratingError ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentCard() {
    final count = feedbackController.text.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE7EEFF), Color(0xFFDCF6EC)],
                  ),
                ),
                child: const Icon(Icons.rate_review_rounded,
                    color: _C.blueDark, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your feedback',
                        style: _outfit(18, FontWeight.w600, _C.ink)),
                    const SizedBox(height: 2),
                    Text(
                      'Tell us what you think',
                      style: GoogleFonts.manrope(color: _C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: feedbackFocus.hasFocus
                  ? [
                BoxShadow(
                  color: _C.blue.withOpacity(0.18),
                  spreadRadius: 4,
                  blurRadius: 0,
                ),
              ]
                  : const [],
            ),
            child: TextFormField(
              controller: feedbackController,
              focusNode: feedbackFocus,
              minLines: 5,
              maxLines: 8,
              maxLength: 500,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: _C.blue,
              style: GoogleFonts.manrope(
                color: _C.ink,
                fontSize: 15,
                height: 1.45,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter your feedback'
                  : null,
              decoration: InputDecoration(
                hintText: 'Write your feedback here...',
                hintStyle: GoogleFonts.manrope(
                  color: const Color(0xFF9AA4C0),
                  fontSize: 13.5,
                ),
                counterText: '',
                errorStyle: GoogleFonts.manrope(
                  color: const Color(0xFFD84B4B),
                  fontSize: 11.5,
                ),
                filled: true,
                fillColor: feedbackFocus.hasFocus ? Colors.white : _C.bg,
                contentPadding: const EdgeInsets.all(16),
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
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$count / 500',
              style: GoogleFonts.manrope(
                color: _C.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
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
                onPressed: _isSubmitting || _sent ? null : _sendFeedback,
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
                    Icon(
                      _sent
                          ? Icons.check_circle_rounded
                          : Icons.send_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      _sent ? 'Feedback sent' : 'Send feedback',
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
                _sent ? Icons.check_rounded : Icons.favorite_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
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
                          'Feedback',
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
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                              const EdgeInsets.fromLTRB(20, 10, 20, 30),
                              children: [
                                Center(child: _logo()),
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(
                                    _sent
                                        ? 'Thank you!'
                                        : 'We value your opinion',
                                    style:
                                    _outfit(24, FontWeight.w700, _C.ink),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    'Your feedback helps us make Social Intelligent better',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      color: _C.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                _ratingCard(),
                                const SizedBox(height: 18),
                                _commentCard(),
                                const SizedBox(height: 22),
                                _submitButton(),
                                const SizedBox(height: 16),

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
                                      'Your feedback is sent securely',
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}