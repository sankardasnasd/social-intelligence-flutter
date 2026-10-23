import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const lilac = Color(0xFFB79CFF);
  static const heart = Color(0xFFFF5D7A);
  static const sun = Color(0xFFFFB84D);
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

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _FeedReel {
  final int id;
  final String creatorName;
  final String creatorPicture;
  final String place;
  final String district;
  final String createdAt;
  final String mediaType;
  final String mediaUrl;
  final String caption;
  int viewCount;
  bool isLiked;
  bool isSaved;
  int likes;
  int comments;

  _FeedReel({
    required this.id,
    required this.creatorName,
    required this.creatorPicture,
    required this.place,
    required this.district,
    required this.createdAt,
    required this.mediaType,
    required this.mediaUrl,
    required this.caption,
    required this.viewCount,
    required this.isLiked,
    required this.isSaved,
    required this.likes,
    required this.comments,
  });

  factory _FeedReel.fromJson(Map<String, dynamic> j) => _FeedReel(
    id: _i(j['id']),
    creatorName: _s(j['creator_name']),
    creatorPicture: _s(j['creator_picture']),
    place: _s(j['place']),
    district: _s(j['district']),
    createdAt: _s(j['created_at']),
    mediaType: _s(j['media_type']).toLowerCase(),
    mediaUrl: _s(j['media_url']),
    caption: _s(j['caption']),
    viewCount: _i(j['view_count']),
    isLiked: j['is_liked'] == true,
    isSaved: j['is_saved'] == true,
    likes: _i(j['likes_count']),
    comments: _i(j['comments_count']),
  );

  String get location => [place, district].where((e) => e.isNotEmpty).join(', ');
}

class OtherUsersReelsPage extends StatefulWidget {
  const OtherUsersReelsPage({Key? key}) : super(key: key);

  @override
  State<OtherUsersReelsPage> createState() => _OtherUsersReelsPageState();
}

class _OtherUsersReelsPageState extends State<OtherUsersReelsPage> {
  List<_FeedReel> _reels = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busyLike = {};
  final Set<int> _busySave = {};

  @override
  void initState() {
    super.initState();
    _fetchOtherUsersReels();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, String> body) async {
    final s = await _Session.load();
    final res = await http
        .post(Uri.parse('${s.url}/myapp/$endpoint/'), body: {'lid': s.lid, ...body})
        .timeout(const Duration(seconds: 15));
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> _fetchOtherUsersReels({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final s = await _Session.load();
      if (s.lid.isEmpty || s.url.isEmpty) throw Exception('Not signed in');

      final uri = Uri.parse('${s.url}/myapp/user_view_other_users_reels/')
          .replace(queryParameters: {'lid': s.lid});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') throw Exception(data['message'] ?? 'Could not load reels');

      final list = (data['data'] as List)
          .map((e) => _FeedReel.fromJson(e as Map<String, dynamic>))
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
        _error = 'Could not load reels. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _openReelDetail(_FeedReel reel) async {
    final updatedCount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => ReelDetailViewerPage(reel: reel),
      ),
    );

    if (updatedCount != null && mounted) {
      setState(() {
        reel.viewCount = updatedCount;
      });
    }
  }

  Future<void> _toggleLike(_FeedReel r) async {
    if (_busyLike.contains(r.id)) return;
    _busyLike.add(r.id);

    final prevLiked = r.isLiked;
    final prevCount = r.likes;
    setState(() {
      r.isLiked = !prevLiked;
      r.likes = prevLiked ? (prevCount > 0 ? prevCount - 1 : 0) : prevCount + 1;
    });

    try {
      final data = await _post('user_toggle_like_reel', {'reel_id': r.id.toString()});
      if (!mounted) return;
      if (data['status'] == 'ok') {
        setState(() {
          r.isLiked = data['is_liked'] == true;
          r.likes = _i(data['total_likes']);
        });
      } else {
        setState(() {
          r.isLiked = prevLiked;
          r.likes = prevCount;
        });
        _snack(_s(data['message']).isEmpty ? 'Could not update like' : _s(data['message']));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          r.isLiked = prevLiked;
          r.likes = prevCount;
        });
        _snack('Network error. Please try again.');
      }
    } finally {
      _busyLike.remove(r.id);
    }
  }

  Future<void> _toggleSave(_FeedReel r) async {
    if (_busySave.contains(r.id)) return;
    _busySave.add(r.id);

    final prev = r.isSaved;
    setState(() => r.isSaved = !prev);

    try {
      final data = await _post('user_toggle_save_reel', {'reel_id': r.id.toString()});
      if (!mounted) return;
      if (data['status'] == 'ok') {
        setState(() => r.isSaved = data['is_saved'] == true);
        _snack(_s(data['message']).isEmpty ? 'Status updated' : _s(data['message']));
      } else {
        setState(() => r.isSaved = prev);
        _snack(_s(data['message']).isEmpty ? 'Could not save reel' : _s(data['message']));
      }
    } catch (_) {
      if (mounted) {
        setState(() => r.isSaved = prev);
        _snack('Network error. Please try again.');
      }
    } finally {
      _busySave.remove(r.id);
    }
  }

  void _openShareBottomSheet(_FeedReel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ShareToFriendsBottomSheet(reelId: r.id.toString()),
    );
  }

  void _openComments(_FeedReel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CommentsBottomSheet(
        reelId: r.id.toString(),
        onCommentAdded: () {
          if (mounted) setState(() => r.comments = r.comments + 1);
        },
      ),
    );
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
        title: const Text('Explore Reels',
            style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 24)),
      ),
      body: _buildBody(),
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
          onPressed: _fetchOtherUsersReels,
          child: const Text('Try again'),
        ),
      );
    }

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () => _fetchOtherUsersReels(showSpinner: false),
      child: _reels.isEmpty
          ? ListView(children: const [
        SizedBox(
          height: 420,
          child: _Message(
              icon: Icons.movie_filter_outlined,
              text: 'No reels available from other users.'),
        ),
      ])
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          final r = _reels[index];
          return _ReelCard(
            reel: r,
            onMediaTap: () => _openReelDetail(r),
            onLike: () => _toggleLike(r),
            onDoubleTapLike: () {
              if (!r.isLiked) _toggleLike(r);
            },
            onComment: () => _openComments(r),
            onShare: () => _openShareBottomSheet(r),
            onSave: () => _toggleSave(r),
          );
        },
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  final _FeedReel reel;
  final VoidCallback onMediaTap;
  final VoidCallback onLike;
  final VoidCallback onDoubleTapLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const _ReelCard({
    required this.reel,
    required this.onMediaTap,
    required this.onLike,
    required this.onDoubleTapLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF36498C).withOpacity(.09),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                _Avatar(name: reel.creatorName, url: reel.creatorPicture, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reel.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15.5, color: _C.ink)),
                      const SizedBox(height: 1),
                      if (reel.location.isNotEmpty)
                        Text(reel.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: _C.muted)),
                      if (reel.createdAt.isNotEmpty)
                        Text(reel.createdAt,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E98B8))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, size: 14, color: _C.muted),
                      const SizedBox(width: 4),
                      Text(
                        _fmt(reel.viewCount),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _C.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onMediaTap,
            child: _MediaThumbnail(reel: reel, onDoubleTap: onDoubleTapLike),
          ),
          if (reel.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Caption(text: reel.caption),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Row(
              children: [
                _LikeButton(liked: reel.isLiked, onTap: onLike),
                Text(_fmt(reel.likes),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink)),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: _C.muted),
                ),
                Text(_fmt(reel.comments),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink)),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.send_rounded, color: _C.muted),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSave,
                  icon: Icon(
                    reel.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: reel.isSaved ? _C.sun : _C.muted,
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

class ReelDetailViewerPage extends StatefulWidget {
  final _FeedReel reel;
  const ReelDetailViewerPage({Key? key, required this.reel}) : super(key: key);

  @override
  State<ReelDetailViewerPage> createState() => _ReelDetailViewerPageState();
}

class _ReelDetailViewerPageState extends State<ReelDetailViewerPage> {
  VideoPlayerController? _videoCtrl;
  bool _initialized = false;
  late int _latestViewCount;

  @override
  void initState() {
    super.initState();
    _latestViewCount = widget.reel.viewCount;

    if (widget.reel.mediaType == 'video' && widget.reel.mediaUrl.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.reel.mediaUrl))

        ..initialize().then((_) {
          if (mounted) {
            setState(() => _initialized = true);
            _videoCtrl?.setLooping(true);
            _videoCtrl?.play();
          }
        });
    }

    _recordWatch();
  }

  Future<void> _recordWatch() async {
    try {
      final s = await _Session.load();
      final res = await http.post(
        Uri.parse('${s.url}/myapp/user_record_watch/'),
        body: {
          'lid': s.lid,
          'reel_id': widget.reel.id.toString(),
          'duration': '1',
        },
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'ok' && data['current_view_count'] != null) {
        if (mounted) {
          setState(() {
            _latestViewCount = _i(data['current_view_count']);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _latestViewCount);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _latestViewCount),
          ),
          title: Text(widget.reel.creatorName, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: widget.reel.mediaType == 'video'
              ? (_initialized
              ? GestureDetector(
            onTap: () {
              setState(() {
                _videoCtrl!.value.isPlaying
                    ? _videoCtrl!.pause()
                    : _videoCtrl!.play();
              });
            },
            child: AspectRatio(
              aspectRatio: _videoCtrl!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_videoCtrl!),
                  if (!_videoCtrl!.value.isPlaying)
                    const Icon(Icons.play_circle_filled, size: 70, color: Colors.white70),
                ],
              ),
            ),
          )
              : const CircularProgressIndicator(color: Colors.white))
              : (widget.reel.mediaUrl.isNotEmpty
              ? InteractiveViewer(
            child: Image.network(
              widget.reel.mediaUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                size: 60,
                color: Colors.white54,
              ),
            ),
          )
              : const Icon(Icons.image, size: 80, color: Colors.white54)),
        ),
      ),
    );
  }
}

class _MediaThumbnail extends StatefulWidget {
  final _FeedReel reel;
  final VoidCallback onDoubleTap;
  const _MediaThumbnail({required this.reel, required this.onDoubleTap});

  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> with SingleTickerProviderStateMixin {
  late final AnimationController _heart =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;

    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (r.mediaType == 'image' && r.mediaUrl.isNotEmpty)
            Image.network(
              r.mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEEF2FF),
                child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 50, color: _C.muted)),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9DB6FF), Color(0xFFB79CFF)],
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
                    size: 72,
                    color: Colors.white.withOpacity(.95),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    r.mediaType == 'video' ? 'Tap to Play Video' : 'Audio Reel',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _heart,
              builder: (context, _) {
                final t = _heart.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                final scale = Curves.elasticOut.transform((t * 1.4).clamp(0.0, 1.0));
                final opacity = t < .6 ? 1.0 : (1 - (t - .6) / .4);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale * 1.1,
                    child: const Icon(Icons.favorite_rounded,
                        size: 96,
                        color: Colors.white,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 24)]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatefulWidget {
  final String text;
  const _Caption({required this.text});

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 90;
    return GestureDetector(
      onTap: long ? () => setState(() => _open = !_open) : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topLeft,
        child: Text(
          widget.text,
          maxLines: _open ? null : 2,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, height: 1.45, color: _C.ink),
        ),
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  const _LikeButton({required this.liked, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);

  @override
  void didUpdateWidget(covariant _LikeButton old) {
    super.didUpdateWidget(old);
    if (old.liked != widget.liked) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.onTap,
      icon: ScaleTransition(
        scale: Tween<double>(begin: .55, end: 1)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)),
        child: Icon(
          widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: widget.liked ? _C.heart : _C.muted,
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
            colors: [_C.blue, _C.lilac], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w700)),
    );

    if (url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
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

class ShareToFriendsBottomSheet extends StatefulWidget {
  final String reelId;
  const ShareToFriendsBottomSheet({Key? key, required this.reelId}) : super(key: key);

  @override
  State<ShareToFriendsBottomSheet> createState() => _ShareToFriendsBottomSheetState();
}

class _ShareToFriendsBottomSheetState extends State<ShareToFriendsBottomSheet> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  bool _failed = false;
  final Set<int> _sentIds = {};
  final Set<int> _sendingIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final s = await _Session.load();
      final uri = Uri.parse('${s.url}/myapp/user_view_friends_to_share/')
          .replace(queryParameters: {'lid': s.lid});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') throw Exception('Failed to load friends');
      if (!mounted) return;
      setState(() {
        _friends = (data['friends'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _sendToFriend(int friendId, String friendName) async {
    if (_sendingIds.contains(friendId) || _sentIds.contains(friendId)) return;

    setState(() => _sendingIds.add(friendId));

    try {
      final s = await _Session.load();
      final res = await http.post(
        Uri.parse('${s.url}/myapp/user_send_reel_to_friend/'),
        body: {
          'lid': s.lid,
          'reel_id': widget.reelId,
          'receiver_id': friendId.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(res.body) as Map<String, dynamic>;

      if (!mounted) return;
      if (data['status'] == 'ok') {
        setState(() {
          _sentIds.add(friendId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reel sent to $friendName!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_s(data['message']).isEmpty ? 'Could not send' : _s(data['message'])),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Failed to send.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingIds.remove(friendId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.58;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: _C.line, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 14),
          const Text('Share with Friends',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _C.line),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.blue));
    }
    if (_failed) {
      return _Message(
        icon: Icons.people_outline_rounded,
        text: 'Could not load friends.',
        action: TextButton(onPressed: _loadFriends, child: const Text('Try again')),
      );
    }
    if (_friends.isEmpty) {
      return const _Message(
        icon: Icons.person_search_rounded,
        text: 'No mutual friends found.\nFollow users to share reels with them.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final f = _friends[index];
        final id = _i(f['id']);
        final name = _s(f['name']);
        final isSent = _sentIds.contains(id);
        final isSending = _sendingIds.contains(id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _Avatar(name: name, url: _s(f['profile_picture']), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5, color: _C.ink)),
                    const SizedBox(height: 2),
                    Text(
                      [_s(f['place']), _s(f['district'])].where((e) => e.isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 12, color: _C.muted),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isSent ? const Color(0xFFE9EFFF) : _C.blue,
                  foregroundColor: isSent ? _C.blue : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: isSent || isSending ? null : () => _sendToFriend(id, name),
                child: isSending
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(isSent ? 'Sent' : 'Send',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final String reelId;
  final VoidCallback onCommentAdded;

  const CommentsBottomSheet({
    Key? key,
    required this.reelId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final s = await _Session.load();
      final uri = Uri.parse('${s.url}/myapp/user_view_and_add_comments/')
          .replace(queryParameters: {'reel_id': widget.reelId});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(res.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') throw Exception('failed');
      if (!mounted) return;
      setState(() {
        _comments = (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final s = await _Session.load();
      final res = await http.post(
        Uri.parse('${s.url}/myapp/user_view_and_add_comments/'),
        body: {'lid': s.lid, 'reel_id': widget.reelId, 'comment_text': text},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'ok') {
        _commentCtrl.clear();
        FocusManager.instance.primaryFocus?.unfocus();
        widget.onCommentAdded();
        await _loadComments(showSpinner: false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_s(data['message']).isEmpty ? 'Could not post comment' : _s(data['message'])),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Network error. Please try again.'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.68;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: _C.line, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Comments',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink)),
                if (!_loading && !_failed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE9EFFF), borderRadius: BorderRadius.circular(999)),
                    child: Text('${_comments.length}',
                        style: const TextStyle(
                            color: _C.blue, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: _C.line),
            Expanded(child: _buildList()),
            const Divider(height: 1, color: _C.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postComment(),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: Color(0xFFA0A9C4)),
                        filled: true,
                        fillColor: _C.bg,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: _C.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: _C.blue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _C.blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _postComment,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _sending
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.blue));
    }
    if (_failed) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: 'Could not load comments.',
        action: TextButton(onPressed: _loadComments, child: const Text('Try again')),
      );
    }
    if (_comments.isEmpty) {
      return const _Message(
        icon: Icons.chat_bubble_outline_rounded,
        text: 'No comments yet. Be the first to comment!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final c = _comments[index];
        final name = _s(c['user_name']);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: name, url: _s(c['profile_picture']), size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      topLeft: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13, color: _C.ink)),
                      const SizedBox(height: 2),
                      Text(_s(c['comment_text']),
                          style: const TextStyle(fontSize: 14, height: 1.4, color: _C.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}