import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// COLORS (same pastel theme)
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
// FOLLOW PAGE
// ============================================================

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});

  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _bgCtrl;
  late AnimationController _enterCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  String baseUrl = '';
  String lid = '';

  bool loading = true;
  bool actionLoading = false;

  int followersCount = 0;
  int followingCount = 0;

  List<Map<String, dynamic>> otherUsers = [];
  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    final curve =
    CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);

    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // INIT + API
  // ============================================================

  Future<void> _initialize() async {
    final sh = await SharedPreferences.getInstance();

    baseUrl = (sh.getString('url') ?? '').trim();
    lid = (sh.getString('lid') ?? '').trim();
    baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

    if (baseUrl.isEmpty || lid.isEmpty) {
      if (mounted) {
        setState(() => loading = false);
        _showMessage('Server URL or login ID not found');
      }
      return;
    }

    await _loadAll();
  }

  String _endpoint(String name) => '$baseUrl/myapp/$name/';

  Future<Map<String, dynamic>> _getApi(String endpoint) async {
    final uri = Uri.parse(_endpoint(endpoint)).replace(
      queryParameters: {'lid': lid},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response');
    }

    if (decoded['status'] != 'ok') {
      throw Exception(decoded['message']?.toString() ?? 'Request failed');
    }

    return decoded;
  }

  Future<List<Map<String, dynamic>>> _getUsers(String endpoint) async {
    final result = await _getApi(endpoint);
    final rawData = result['data'];

    if (rawData is! List) return [];

    return rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final results = await Future.wait([
        _getUsers('view_other_users'),
        _getUsers('view_followers'),
        _getUsers('view_following'),
        _getApi('view_follow_counts'),
      ]);

      if (!mounted) return;

      setState(() {
        otherUsers = results[0] as List<Map<String, dynamic>>;
        followers = results[1] as List<Map<String, dynamic>>;
        following = results[2] as List<Map<String, dynamic>>;

        final counts = results[3] as Map<String, dynamic>;
        followersCount = int.tryParse('${counts['followers_count']}') ?? 0;
        followingCount = int.tryParse('${counts['following_count']}') ?? 0;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage('Unable to load data: $e');
    }
  }

  Future<void> _followUser(Map<String, dynamic> user) async {
    await _performAction(endpoint: 'user_follow', user: user);
  }

  Future<void> _unfollowUser(Map<String, dynamic> user) async {
    final name = user['name']?.toString() ?? 'this user';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unfollow user?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _C.ink)),
        content: Text(
          'Do you want to unfollow $name?',
          style: GoogleFonts.manrope(color: _C.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: _C.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.flag,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await _performAction(endpoint: 'user_unfollow', user: user);
  }

  Future<void> _performAction({
    required String endpoint,
    required Map<String, dynamic> user,
  }) async {
    if (actionLoading) return;

    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      _showMessage('User ID not found');
      return;
    }

    setState(() => actionLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_endpoint(endpoint)),
        body: {'lid': lid, 'user_id': userId},
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ?? 'Action failed'
              : 'Invalid response',
        );
      }

      if (!mounted) return;
      _showMessage(decoded['message']?.toString() ?? 'Success');
      await _loadAll();
    } catch (e) {
      if (mounted) _showMessage('Action failed: $e');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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

  TextStyle _outfit(double size, FontWeight w, Color c) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: -0.2,
    );
  }

  Widget _profileImage(Map<String, dynamic> user) {
    final picture = user['profile_picture']?.toString() ?? '';
    final name = user['name']?.toString() ?? '';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE7EEFF), Color(0xFFEFE7FF)],
        ),
        border: Border.all(color: _C.line, width: 1.5),
        image: picture.isNotEmpty
            ? DecorationImage(image: NetworkImage(picture), fit: BoxFit.cover)
            : null,
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: picture.isEmpty
          ? Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: _outfit(20, FontWeight.w700, _C.blueDark),
        ),
      )
          : null,
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
    bool destructive = false,
  }) {
    if (filled) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: destructive
              ? null
              : const LinearGradient(colors: [_C.blueDark, _C.violet]),
          color: destructive ? _C.flag.withOpacity(0.12) : null,
          boxShadow: filled && !destructive
              ? [
            BoxShadow(
              color: _C.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: actionLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? Colors.transparent : Colors.transparent,
            foregroundColor: destructive ? _C.flag : Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: actionLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? _C.flag : _C.ink,
        side: BorderSide(
          color: destructive ? _C.flag.withOpacity(0.4) : _C.line,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user, {required String listType}) {
    final name = user['name']?.toString() ?? 'Unknown user';
    final isFollowing = user['is_following'] == true;

    late String buttonLabel;
    late VoidCallback buttonAction;
    late bool filled;
    bool destructive = false;

    if (listType == 'following') {
      buttonLabel = 'Unfollow';
      buttonAction = () => _unfollowUser(user);
      filled = false;
      destructive = true;
    } else if (isFollowing) {
      buttonLabel = 'Unfollow';
      buttonAction = () => _unfollowUser(user);
      filled = false;
      destructive = true;
    } else if (user['follows_you'] == true || listType == 'followers') {
      buttonLabel = 'Follow Back';
      buttonAction = () => _followUser(user);
      filled = true;
    } else {
      buttonLabel = 'Follow';
      buttonAction = () => _followUser(user);
      filled = true;
    }

    final place = [user['place'], user['district']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _profileImage(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _outfit(15.5, FontWeight.w600, _C.ink),
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(color: _C.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(
            label: buttonLabel,
            onPressed: buttonAction,
            filled: filled,
            destructive: destructive,
          ),
        ],
      ),
    );
  }

  Widget _userList(List<Map<String, dynamic>> users, {required String listType}) {
    if (users.isEmpty) {
      return RefreshIndicator(
        color: _C.blue,
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.people_outline_rounded,
                size: 56, color: _C.muted.withOpacity(0.45)),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'No users found',
                style: GoogleFonts.manrope(
                  color: _C.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: _loadAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return _userCard(users[index], listType: listType);
        },
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _tabController.animateTo(1),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Text(
                    '$followersCount',
                    style: _outfit(24, FontWeight.w700, _C.blueDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Followers',
                    style: GoogleFonts.manrope(
                      color: _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 40, width: 1.5, color: _C.line),
          Expanded(
            child: InkWell(
              onTap: () => _tabController.animateTo(2),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Text(
                    '$followingCount',
                    style: _outfit(24, FontWeight.w700, _C.violet),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Following',
                    style: GoogleFonts.manrope(
                      color: _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated soft gradient background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(_bgCtrl.value);
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + t * 0.7, -1),
                      end: Alignment(1, 1 - t * 0.7),
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

          SafeArea(
            child: Column(
              children: [
                // Top bar
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
                          'People',
                          textAlign: TextAlign.center,
                          style: _outfit(20, FontWeight.w600, _C.ink),
                        ),
                      ),
                      Material(
                        color: Colors.white.withOpacity(0.92),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _C.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: loading || actionLoading ? null : _loadAll,
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: _C.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: loading
                          ? const Center(
                        child: CircularProgressIndicator(color: _C.blue),
                      )
                          : Column(
                        children: [
                          _buildStats(),

                          if (actionLoading)
                            const LinearProgressIndicator(
                              color: _C.blue,
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
                            ),

                          // Soft tab bar
                          Container(
                            margin:
                            const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _C.line),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [_C.blueDark, _C.violet],
                                ),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: _C.muted,
                              labelStyle: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              unselectedLabelStyle: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              tabs: const [
                                Tab(text: 'Discover'),
                                Tab(text: 'Followers'),
                                Tab(text: 'Following'),
                              ],
                            ),
                          ),

                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _userList(otherUsers, listType: 'other'),
                                _userList(followers,
                                    listType: 'followers'),
                                _userList(following,
                                    listType: 'following'),
                              ],
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
        ],
      ),
    );
  }
}