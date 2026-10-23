import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const lilac = Color(0xFFB79CFF);
  static const heart = Color(0xFFFF5D7A);
}

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

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;

class _InteractionReel {
  final int reelId;
  final String creatorName;
  final String creatorPicture;
  final String place;
  final String district;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final String userComment;
  final String actionTime;

  _InteractionReel({
    required this.reelId,
    required this.creatorName,
    required this.creatorPicture,
    required this.place,
    required this.district,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.userComment,
    required this.actionTime,
  });

  factory _InteractionReel.fromJson(Map<String, dynamic> j) => _InteractionReel(
    reelId: _i(j['reel_id']),
    creatorName: _s(j['creator_name']),
    creatorPicture: _s(j['creator_picture']),
    place: _s(j['place']),
    district: _s(j['district']),
    mediaUrl: _s(j['media_url']),
    mediaType: _s(j['media_type']).toLowerCase(),
    caption: _s(j['caption']),
    likesCount: _i(j['likes_count']),
    commentsCount: _i(j['comments_count']),
    userComment: _s(j['user_comment']),
    actionTime: _s(j['action_time']),
  );

  String get location => [place, district].where((e) => e.isNotEmpty).join(', ');
}

class LikedCommentedReelsPage extends StatefulWidget {
  const LikedCommentedReelsPage({Key? key}) : super(key: key);

  @override
  State<LikedCommentedReelsPage> createState() => _LikedCommentedReelsPageState();
}

class _LikedCommentedReelsPageState extends State<LikedCommentedReelsPage> {
  String _activeTab = 'liked'; // 'liked' or 'commented'
  List<_InteractionReel> _reels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  Future<void> _fetchReels({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final s = await _Session.load();
      if (s.lid.isEmpty || s.url.isEmpty) throw Exception('Session missing');

      final uri = Uri.parse('${s.url}/myapp/user_view_liked_commented_reels/')
          .replace(queryParameters: {'lid': s.lid, 'type': _activeTab});

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') {
        throw Exception(data['message'] ?? 'Failed to load reels');
      }

      final list = (data['data'] as List)
          .map((e) => _InteractionReel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _reels = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load data. Check your connection.';
        _loading = false;
      });
    }
  }

  void _switchTab(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
    _fetchReels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Text(
          'My Activity',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          // Selector Tabs (Liked / Commented)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'Liked Reels',
                      icon: Icons.favorite_rounded,
                      isActive: _activeTab == 'liked',
                      onTap: () => _switchTab('liked'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TabButton(
                      title: 'Commented',
                      icon: Icons.comment_rounded,
                      isActive: _activeTab == 'commented',
                      onTap: () => _switchTab('commented'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content List
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54, color: _C.lilac),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.muted, fontSize: 14.5)),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _C.blue),
                onPressed: () => _fetchReels(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () => _fetchReels(showSpinner: false),
      child: _reels.isEmpty
          ? ListView(
        children: [
          SizedBox(
            height: 380,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _activeTab == 'liked'
                        ? Icons.favorite_border_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: _C.lilac,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activeTab == 'liked'
                        ? 'No liked reels found.'
                        : 'No commented reels found.',
                    style: const TextStyle(color: _C.muted, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          final r = _reels[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF36498C).withOpacity(.07),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _Avatar(name: r.creatorName, url: r.creatorPicture, size: 42),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.creatorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _C.ink),
                            ),
                            if (r.location.isNotEmpty)
                              Text(
                                r.location,
                                style: const TextStyle(fontSize: 12, color: _C.muted),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        _activeTab == 'liked'
                            ? Icons.favorite_rounded
                            : Icons.comment_rounded,
                        color: _activeTab == 'liked' ? _C.heart : _C.blue,
                        size: 22,
                      ),
                    ],
                  ),
                ),

                // Media Content
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    height: 250,
                    width: double.infinity,
                    color: Colors.black12,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (r.mediaType == 'image' && r.mediaUrl.isNotEmpty)
                          Image.network(
                            r.mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  size: 48, color: _C.muted),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_C.blue, _C.lilac],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  r.mediaType == 'video'
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.graphic_eq_rounded,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.mediaType == 'video' ? 'Video Reel' : 'Audio Reel',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // User's Comment Box (if viewing commented tab)
                if (_activeTab == 'commented' && r.userComment.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_rounded, size: 16, color: _C.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.userComment,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _C.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Caption
                if (r.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      r.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: _C.ink),
                    ),
                  ),

                // Footer stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 16, color: _C.heart),
                      const SizedBox(width: 4),
                      Text('${r.likesCount}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13, color: _C.ink)),
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 16, color: _C.muted),
                      const SizedBox(width: 4),
                      Text('${r.commentsCount}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13, color: _C.ink)),
                      const Spacer(),
                      Text(r.actionTime,
                          style: const TextStyle(fontSize: 11, color: _C.muted)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _C.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : _C.muted),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isActive ? Colors.white : _C.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String url;
  final double size;
  const _Avatar({required this.name, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_C.blue, _C.lilac],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}