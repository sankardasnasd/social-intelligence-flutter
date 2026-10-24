import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:social_intelligent/user/saved_reels_page.dart';
import 'package:social_intelligent/user/sent%20feedback.dart';
import 'package:social_intelligent/user/upload_reel_page.dart';
import 'package:social_intelligent/user/view%20other%20users.dart';
import 'package:social_intelligent/user/view%20own%20reels.dart';
import 'package:social_intelligent/user/view_received_shared_reels_page.dart';
import 'package:social_intelligent/user/view_reels_analysis.dart';
import 'package:social_intelligent/user/posting_time_page.dart';
import 'package:social_intelligent/user/reach_prediction_page.dart';
import 'package:social_intelligent/user/trending_topics_page.dart';

import '../login.dart';
import 'change password.dart';
import 'follow page.dart';
import 'liked_commented_reels_page.dart';
import 'manage complaints.dart';
import 'other_users_reels_page.dart';
import 'profile.dart';

// ============================================================
// COLORS (soft pastel theme)
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
// FEATURE MODEL
// ============================================================

class _Feature {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _Feature(this.key, this.icon, this.title, this.subtitle, this.accent);
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ---------------- LOCATION STATE ----------------
  final Location _location = Location();

  bool _locLoading = true;
  String _place = '';
  String _district = '';
  String _state = '';
  String _lat = '';
  String _lon = '';
  String _locError = '';
  String _name = '';

  // ---------------- ANIMATION ----------------
  late final AnimationController _bgCtrl;
  late final AnimationController _blobCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shineCtrl;
  late final AnimationController _enterCtrl;
  late final AnimationController _spinCtrl;

  // ---------------- FEATURES ----------------
  static const _reels = [
    _Feature('my_reels', Icons.video_library_rounded, 'My Reels',
        'View your own reels', _C.blue),
    _Feature('analysis', Icons.analytics_rounded, 'Reel Analysis',
        'Topic, sentiment, safety', _C.violet),
    _Feature('other_reels', Icons.people_alt_rounded, 'Others Reels',
        'Watch reels from other users', _C.mint),
  ];

  static const _insights = [
    _Feature('post_time', Icons.schedule_rounded, 'Best Time',
        'When to post', _C.peach),
    _Feature('reach', Icons.bolt_rounded, 'Reach',
        'Predicted engagement', _C.blue),
    _Feature('trending', Icons.trending_up_rounded, 'Trending',
        'Rising topics', _C.mint),
  ];

  static const _community = [
    _Feature('like_comment', Icons.favorite_rounded, 'Like & Comment',
        'React to reels', _C.flag),
    _Feature('share', Icons.share_rounded, 'Share Reels',
        'Send to friends', _C.blue),
    _Feature('saved', Icons.bookmark_rounded, 'Saved Reels',
        'Your saved list', _C.sun),
    _Feature('follow', Icons.group_add_rounded, 'Follow',
        'Interact with creators', _C.lilac),
  ];

  static const _support = [
    _Feature('feedback', Icons.rate_review_rounded, 'Feedback',
        'Tell us what you think', _C.mint),
    _Feature('complaints', Icons.support_agent_rounded, 'Complaints',
        'Submit and view replies', _C.peach),
  ];

  static const _account = [
    _Feature('profile', Icons.manage_accounts_rounded, 'Manage Profile',
        'Update your details', _C.blue),
    _Feature('password', Icons.key_rounded, 'Change Password',
        'Keep your account safe', _C.violet),
    _Feature('logout', Icons.logout_rounded, 'Logout',
        'Sign out of this device', _C.flag),
  ];

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

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
      duration: const Duration(seconds: 2),
    )..repeat();

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _loadSaved();
    _fetchLocation();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _shineCtrl.dispose();
    _spinCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _loadSaved() async {
    final sh = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = sh.getString('name') ?? '';
      if (_lat.isEmpty) _lat = sh.getString('lat') ?? '';
      if (_lon.isEmpty) _lon = sh.getString('lon') ?? '';
    });
  }

  String _first(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;

    setState(() {
      _locLoading = true;
      _locError = '';
    });
    _spinCtrl.repeat();

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }
      if (!serviceEnabled) {
        _locError = 'Turn on GPS to see your location';
        return;
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission != PermissionStatus.granted) {
        _locError = 'Allow location permission';
        return;
      }

      final gps = await _location.getLocation();
      if (gps.latitude == null || gps.longitude == null) {
        _locError = 'GPS coordinates unavailable';
        return;
      }

      final lat = gps.latitude!;
      final lon = gps.longitude!;

      if (!mounted) return;
      setState(() {
        _lat = lat.toStringAsFixed(5);
        _lon = lon.toStringAsFixed(5);
      });

      final sh = await SharedPreferences.getInstance();
      await sh.setString('lat', lat.toString());
      await sh.setString('lon', lon.toString());

      final list = await geo.placemarkFromCoordinates(lat, lon);
      if (list.isEmpty) {
        _locError = 'Address not found';
        return;
      }

      final f = list.first;

      String district = '';
      for (final a in list) {
        district = _first([a.subAdministrativeArea]);
        if (district.isNotEmpty) break;
      }

      final place = _first([
        f.subLocality,
        f.locality,
        f.name,
        f.thoroughfare,
        f.street,
      ]);

      final state = _first(list.map((a) => a.administrativeArea).toList());

      if (!mounted) return;
      setState(() {
        _place = place;
        _district = district;
        _state = state;
      });
    } catch (e) {
      debugPrint('Home location error: $e');
      _locError = 'Unable to fetch address';
    } finally {
      _spinCtrl.stop();
      if (mounted) {
        setState(() {
          _locLoading = false;
        });
      }
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _open(String key) {
    switch (key) {
      case 'home':
        return;

      case 'upload':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadReelPage()),
        );
        return;

      case 'my_reels':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewOwnReels()),
        );
        return;

      case 'analysis':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewReelAnalysisPage()),
        );
        return;

      case 'other_reels':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OtherUsersReelsPage()),
        );
        return;

    // ---- CONNECTED MODULES (Posting Time, Reach, Trending) ----
      case 'post_time':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostingTimePage()),
        );
        return;

      case 'reach':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReachPredictionPage()),
        );
        return;

      case 'trending':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrendingTopicsPage()),
        );
        return;

      case 'like_comment':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LikedCommentedReelsPage()),
        );
        return;

      case 'share':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SharedReelsHubPage()),
        );
        return;

      case 'saved':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedReelsPage()),
        );
        return;

      case 'follow':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FollowPage()),
        );
        return;

      case 'feedback':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FeedbackPage()),
        );
        return;

      case 'complaints':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComplaintPage()),
        );
        return;

      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
        return;

      case 'password':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        );
        return;

      case 'logout':
        _confirmLogout();
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Page not connected yet',
          style: GoogleFonts.manrope(color: _C.ink),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _C.line),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout', style: _outfit(20, FontWeight.w600, _C.ink)),
        content: Text(
          'Do you want to sign out?',
          style: GoogleFonts.manrope(color: _C.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: _C.blueDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.flag,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ??
        false;

    if (!ok || !mounted) return;

    final sh = await SharedPreferences.getInstance();
    await sh.remove('lid');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  // ============================================================
  // BUILD
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

  Animation<double> _iv(double a, double b) {
    return CurvedAnimation(
      parent: _enterCtrl,
      curve: Interval(a, b, curve: Curves.easeOutCubic),
    );
  }

  Widget _reveal(double start, Widget child) {
    final anim = _iv(start, math.min(1.0, start + 0.4));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        final exit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text('Exit App',
                style: _outfit(20, FontWeight.w600, _C.ink)),
            content: Text(
              'Are you sure you want to exit Social Intelligent?',
              style: GoogleFonts.manrope(color: _C.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
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
                child: const Text('Exit'),
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
            // ---------------- BACKGROUND ----------------
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
              left: size.width - 200,
              top: 120,
              child: IgnorePointer(
                child: _blob(
                  size: 300,
                  colors: const [
                    Color(0xFFC9D8FF),
                    Color(0xFFE0D4FF),
                    Color(0xFFC7F3E3),
                  ],
                  opacity: 0.8,
                  reverse: false,
                ),
              ),
            ),
            Positioned(
              left: -90,
              top: size.height * 0.55,
              child: IgnorePointer(
                child: _blob(
                  size: 240,
                  colors: const [Color(0xFFFFE0D4), Color(0xFFFFF0C8)],
                  opacity: 0.7,
                  reverse: true,
                ),
              ),
            ),
            _confetti(size.width * 0.82, size.height * 0.30, 12, _C.peach, 0.0, 1.0),
            _confetti(size.width * 0.08, size.height * 0.42, 10, _C.sun, 0.4, 1.0),
            _confetti(size.width * 0.90, size.height * 0.68, 16, _C.lilac, 0.7, 0.7),

            // ---------------- CONTENT ----------------
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _reveal(0.0, _topBar()),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                          children: [
                            _reveal(0.08, _greeting()),
                            const SizedBox(height: 16),
                            _reveal(0.14, _hero()),
                            const SizedBox(height: 26),

                            _reveal(0.22, _sectionTitle('Your reels')),
                            _reveal(0.24, _grid(_reels)),
                            const SizedBox(height: 22),

                            _reveal(0.32, _sectionTitle('Insights')),
                            _reveal(0.34, _insightRow()),
                            const SizedBox(height: 22),

                            _reveal(0.42, _sectionTitle('Community')),
                            _reveal(0.44, _grid(_community)),
                            const SizedBox(height: 22),

                            _reveal(0.52, _sectionTitle('Support')),
                            _reveal(0.54, _grid(_support)),
                            const SizedBox(height: 22),

                            _reveal(0.60, _sectionTitle('Account')),
                            _reveal(0.62, _accountCard()),
                            const SizedBox(height: 22),

                            Center(
                              child: Text(
                                '© 2026 Social Intelligent',
                                style: GoogleFonts.manrope(
                                  color: _C.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------------- BOTTOM BAR ----------------
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _bottomBar(),
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
  // TOP BAR (current location details)
  // ============================================================

  Widget _topBar() {
    final hasAddress = _place.isNotEmpty || _district.isNotEmpty;

    String title;
    if (_locLoading && !hasAddress) {
      title = 'Detecting your location...';
    } else if (hasAddress) {
      title = _place.isNotEmpty ? _place : _district;
    } else {
      title = _locError.isNotEmpty ? _locError : 'Location not available';
    }

    final subParts = <String>[
      if (_district.isNotEmpty && _district != title) _district,
      if (_state.isNotEmpty) _state,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: _C.shadow.withOpacity(0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (context, _) {
                              final t = _pulseCtrl.value;
                              return Container(
                                width: 40 + 14 * t,
                                height: 40 + 14 * t,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _C.mint.withOpacity((1 - t) * 0.8),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_C.blue, _C.mint],
                              ),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT LOCATION',
                            style: GoogleFonts.manrope(
                              color: _C.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _outfit(18, FontWeight.w600, _C.ink),
                          ),
                          if (subParts.isNotEmpty)
                            Text(
                              subParts.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: _C.muted,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Material(
                      color: _C.blue.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _locLoading ? null : _fetchLocation,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: RotationTransition(
                            turns: _spinCtrl,
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: _C.blueDark,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_lat.isNotEmpty && _lon.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _pill(Icons.explore_rounded, 'Lat $_lat', _C.blue),
                      const SizedBox(width: 8),
                      _pill(Icons.explore_outlined, 'Lon $_lon', _C.violet),
                      const Spacer(),
                      _livePill(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color c) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: _C.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _livePill() {
    final ok = _locError.isEmpty && !_locLoading;
    final c = ok ? _C.mint : _C.sun;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (context, _) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withOpacity(1 - 0.5 * _floatCtrl.value),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            ok ? 'Live' : 'Updating',
            style: GoogleFonts.manrope(
              color: _C.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GREETING + HERO
  // ============================================================

  Widget _greeting() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name.isEmpty ? 'Welcome back' : 'Welcome back, $_name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _outfit(24, FontWeight.w700, _C.ink),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Share reels that are ',
                    style: _outfit(14, FontWeight.w500, _C.muted, spacing: 0),
                  ),
                  _swapWord(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _words = [
    ['safe.', 0xFF5FD3B0],
    ['trending.', 0xFF5F85FF],
    ['loved.', 0xFFFFAB91],
  ];

  Widget _swapWord() {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) {
        final i = (_blobCtrl.value * 12).floor() % 3;
        final word = _words[i][0] as String;
        final color = Color(_words[i][1] as int);

        return SizedBox(
          height: 22,
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, anim) {
                final incoming = child.key == ValueKey(word);
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: incoming ? const Offset(0, 1) : const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: Text(
                word,
                key: ValueKey(word),
                style: _outfit(14, FontWeight.w700, color, spacing: 0),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5F85FF), Color(0xFF8F7BFF), Color(0xFF5FD3B0)],
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -34,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Safety check on every upload',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ready to post\na new reel?',
                style: _outfit(28, FontWeight.w700, Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a reel to get its safety result, predicted reach and the best time to post.',
                style: GoogleFonts.manrope(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: Stack(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const UploadReelPage()),
                        );
                      },
                      icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                      label: Text(
                        'Upload Reel',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _C.blueDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                              final p = ((_shineCtrl.value - 0.55) / 0.45)
                                  .clamp(0.0, 1.0);
                              final left = -0.6 + 1.9 * p;
                              return Align(
                                alignment: Alignment((left / 0.64) * 2 - 1, 0),
                                child: FractionallySizedBox(
                                  widthFactor: 0.30,
                                  heightFactor: 1,
                                  child: Transform(
                                    transform: Matrix4.skewX(-0.36),
                                    child: Container(
                                      color: _C.blue.withOpacity(0.18),
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
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTIONS
  // ============================================================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_C.blue, _C.mint],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(text, style: _outfit(19, FontWeight.w600, _C.ink)),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _C.line),
      boxShadow: [
        BoxShadow(
          color: _C.shadow.withOpacity(0.10),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _grid(List<_Feature> items) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children:
          items.map((f) => SizedBox(width: w, child: _tile(f))).toList(),
        );
      },
    );
  }

  Widget _tile(_Feature f) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDeco(),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(f.key),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            f.accent.withOpacity(0.28),
                            f.accent.withOpacity(0.10),
                          ],
                        ),
                      ),
                      child: Icon(f.icon, color: f.accent, size: 24),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: _C.muted.withOpacity(0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _outfit(16, FontWeight.w600, _C.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  f.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: _C.muted,
                    fontSize: 11.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _insightRow() {
    return Row(
      children: [
        for (int i = 0; i < _insights.length; i++) ...[
          Expanded(child: _compactTile(_insights[i])),
          if (i != _insights.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _compactTile(_Feature f) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDeco(),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(f.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        f.accent.withOpacity(0.30),
                        f.accent.withOpacity(0.10),
                      ],
                    ),
                  ),
                  child: Icon(f.icon, color: f.accent, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  f.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _outfit(14.5, FontWeight.w600, _C.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  f.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: _C.muted,
                    fontSize: 10.8,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountCard() {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (int i = 0; i < _account.length; i++) ...[
            _accountRow(_account[i]),
            if (i != _account.length - 1)
              const Divider(height: 1, indent: 70, color: _C.line),
          ],
        ],
      ),
    );
  }

  Widget _accountRow(_Feature f) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _open(f.key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: f.accent.withOpacity(0.14),
              ),
              child: Icon(f.icon, color: f.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.title,
                    style: _outfit(15.5, FontWeight.w600, _C.ink),
                  ),
                  Text(
                    f.subtitle,
                    style: GoogleFonts.manrope(
                      color: _C.muted,
                      fontSize: 11.8,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _C.muted.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _bottomBar() {
    Widget item(IconData icon, String label, bool active, String key) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(key),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: active ? _C.blueDark : _C.muted),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? _C.blueDark : _C.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.18),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          item(Icons.home_rounded, 'Home', true, 'home'),
          item(Icons.video_library_rounded, 'Reels', false, 'my_reels'),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _open('upload'),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_C.blueDark, _C.violet],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.blue.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
          item(Icons.trending_up_rounded, 'Trending', false, 'trending'),
          item(Icons.person_rounded, 'Profile', false, 'profile'),
        ],
      ),
    );
  }

  // ============================================================
  // BACKGROUND HELPERS
  // ============================================================

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
}