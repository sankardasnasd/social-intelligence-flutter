import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Colours (private to this file so they do not clash with your other files)
class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const lilac = Color(0xFFB79CFF);
}

// ---------------------------------------------------------------
// Saved login id and server url (SharedPreferences keys: 'lid', 'url')
// ---------------------------------------------------------------
class _Session {
  final String url;
  final String lid;
  _Session(this.url, this.lid);

  static Future<_Session> load() async {
    final sh = await SharedPreferences.getInstance();
    var url = (sh.get('url')?.toString() ?? '').trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return _Session(url, (sh.get('lid')?.toString() ?? '').trim());
  }
}

// ---------------------------------------------------------------
// Model
// ---------------------------------------------------------------
class OtherUser {
  final int id;
  final int loginId;
  final String name;
  final String profilePicture;
  final String region;
  final String place;
  final String district;
  bool isFollowing;
  int followersCount;
  int followingCount;

  OtherUser({
    required this.id,
    required this.loginId,
    required this.name,
    required this.profilePicture,
    required this.region,
    required this.place,
    required this.district,
    required this.isFollowing,
    required this.followersCount,
    required this.followingCount,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();
  static int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;

  factory OtherUser.fromJson(Map<String, dynamic> j) => OtherUser(
    id: _i(j['id']),
    loginId: _i(j['login_id']),
    name: _s(j['name']),
    profilePicture: _s(j['profile_picture']),
    region: _s(j['region']),
    place: _s(j['place']),
    district: _s(j['district']),
    isFollowing: j['is_following'] == true,
    followersCount: _i(j['followers_count']),
    followingCount: _i(j['following_count']),
  );

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
  String get location => [place, district].where((e) => e.isNotEmpty).join(', ');
}

// ---------------------------------------------------------------
// Screen
// ---------------------------------------------------------------
class ViewOtherUsers extends StatefulWidget {
  const ViewOtherUsers({super.key});

  @override
  State<ViewOtherUsers> createState() => _ViewOtherUsersState();
}

class _ViewOtherUsersState extends State<ViewOtherUsers> {
  List<OtherUser> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final Set<int> _busy = {}; // user ids with a follow request in progress

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ---------------- API calls ----------------
  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final s = await _Session.load();
      if (s.lid.isEmpty || s.url.isEmpty) throw Exception('Not signed in');

      final uri = Uri.parse('${s.url}/myapp/view_other_users/')
          .replace(queryParameters: {'lid': s.lid});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'ok') throw Exception(body['message'] ?? 'Could not load users');

      final list = (body['data'] as List)
          .map((e) => OtherUser.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load users. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  /// Follows or unfollows. The list is updated only after the server says ok.
  Future<void> _toggleFollow(OtherUser u) async {
    if (_busy.contains(u.id)) return;
    setState(() => _busy.add(u.id));

    final wasFollowing = u.isFollowing;
    try {
      final s = await _Session.load();
      final endpoint = wasFollowing ? 'user_unfollow' : 'user_follow';
      final res = await http
          .post(
        Uri.parse('${s.url}/myapp/$endpoint/'),
        body: {'lid': s.lid, 'user_id': u.id.toString()},
      )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['status'] == 'ok') {
        u.isFollowing = !wasFollowing;
        final next = u.followersCount + (wasFollowing ? -1 : 1);
        u.followersCount = next < 0 ? 0 : next;
      } else {
        _snack(body['message']?.toString() ?? 'Something went wrong');
      }
    } catch (_) {
      _snack('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  /// Reads follower / following counts of one user (used by the details sheet)
  Future<void> _loadCounts(OtherUser u) async {
    try {
      final s = await _Session.load();
      final uri = Uri.parse('${s.url}/myapp/view_follow_details/')
          .replace(queryParameters: {'user_id': u.id.toString(), 'lid': s.lid});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'ok') {
        u.followersCount = OtherUser._i(body['followers_count']);
        u.followingCount = OtherUser._i(body['following_count']);
        if (body['is_following'] != null) u.isFollowing = body['is_following'] == true;
      }
    } catch (_) {
      // keep the counts we already have
    }
  }

  List<OtherUser> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((u) =>
    u.name.toLowerCase().contains(q) ||
        u.place.toLowerCase().contains(q) ||
        u.district.toLowerCase().contains(q))
        .toList();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Text('People',
            style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name or place',
                hintStyle: const TextStyle(color: _C.muted),
                prefixIcon: const Icon(Icons.search_rounded, color: _C.muted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _C.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _C.blue, width: 1.6),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.blue));
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _C.blue),
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }

    final users = _filtered;
    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () => _load(showSpinner: false),
      child: users.isEmpty
          ? ListView(children: [
        SizedBox(
          height: 360,
          child: _Message(
            icon: Icons.people_outline_rounded,
            text: _query.isEmpty ? 'No other users yet.' : 'No users match your search.',
          ),
        ),
      ])
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: users.length,
        itemBuilder: (context, i) {
          final u = users[i];
          final delay = (i < 10 ? i : 10) * 70;
          return TweenAnimationBuilder<double>(
            key: ValueKey(u.id),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 420 + delay),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, 26 * (1 - v)), child: child),
            ),
            child: _UserCard(
              user: u,
              busy: _busy.contains(u.id),
              onTap: () => _showDetails(u),
              onFollow: () => _toggleFollow(u),
            ),
          );
        },
      ),
    );
  }

  void _showDetails(OtherUser u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _UserSheet(
        user: u,
        loadCounts: _loadCounts,
        onToggle: _toggleFollow,
      ),
    ).then((_) {
      // the list behind the sheet may need to show the new follow state
      if (mounted) setState(() {});
    });
  }
}

// ---------------------------------------------------------------
// Details sheet
// ---------------------------------------------------------------
class _UserSheet extends StatefulWidget {
  final OtherUser user;
  final Future<void> Function(OtherUser) loadCounts;
  final Future<void> Function(OtherUser) onToggle;
  const _UserSheet({required this.user, required this.loadCounts, required this.onToggle});

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.loadCounts(widget.user).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    await widget.onToggle(widget.user);
    if (!mounted) return;
    await widget.loadCounts(widget.user); // refresh the real numbers from the server
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: _C.line, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 22),
            _Avatar(user: u, size: 96),
            const SizedBox(height: 14),
            Text(u.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _C.ink)),
            if (u.location.isNotEmpty || u.region.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(u.location.isEmpty ? u.region : '${u.location} (${u.region})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _C.muted)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Followers', value: u.followersCount)),
                Container(width: 1, height: 40, color: _C.line),
                Expanded(child: _Stat(label: 'Following', value: u.followingCount)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: u.isFollowing
                  ? OutlinedButton(
                onPressed: _busy ? null : _toggle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.ink,
                  side: const BorderSide(color: _C.line, width: 1.6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy ? const _Spin(color: _C.blue) : const Text('Following'),
              )
                  : FilledButton(
                onPressed: _busy ? null : _toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy ? const _Spin(color: Colors.white) : const Text('Follow'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------
class _UserCard extends StatelessWidget {
  final OtherUser user;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onFollow;
  const _UserCard({
    required this.user,
    required this.busy,
    required this.onTap,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF36498C).withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                _Avatar(user: user, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: _C.ink)),
                      const SizedBox(height: 2),
                      Text(user.location.isEmpty ? user.region : user.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: _C.muted)),
                      const SizedBox(height: 2),
                      Text('${user.followersCount} followers',
                          style: const TextStyle(
                              fontSize: 12, color: _C.blue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _FollowButton(following: user.isFollowing, busy: busy, onPressed: onFollow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool following;
  final bool busy;
  final VoidCallback onPressed;
  const _FollowButton({required this.following, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: following
          ? OutlinedButton(
        key: const ValueKey('following'),
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.ink,
          side: const BorderSide(color: _C.line, width: 1.5),
          minimumSize: const Size(96, 38),
          padding: pad,
          shape: shape,
        ),
        child: busy ? const _Spin(color: _C.blue) : const Text('Following'),
      )
          : FilledButton(
        key: const ValueKey('follow'),
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _C.blue,
          minimumSize: const Size(96, 38),
          padding: pad,
          shape: shape,
        ),
        child: busy ? const _Spin(color: Colors.white) : const Text('Follow'),
      ),
    );
  }
}

class _Spin extends StatelessWidget {
  final Color color;
  const _Spin({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(v.round().toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _C.ink)),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: _C.muted)),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final OtherUser user;
  final double size;
  const _Avatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [_C.blue, _C.lilac], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(user.initial,
          style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w700)),
    );

    if (user.profilePicture.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        user.profilePicture,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _C.lilac),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.muted, fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}