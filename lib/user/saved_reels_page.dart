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
  static const sun = Color(0xFFFFB84D);
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

class _SavedReel {
  final int reelId;
  final String creatorName;
  final String creatorPicture;
  final String place;
  final String district;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final String createdAt;
  bool isLiked;
  int likesCount;
  int commentsCount;

  _SavedReel({
    required this.reelId,
    required this.creatorName,
    required this.creatorPicture,
    required this.place,
    required this.district,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    required this.isLiked,
    required this.likesCount,
    required this.commentsCount,
  });

  factory _SavedReel.fromJson(Map<String, dynamic> j) => _SavedReel(
    reelId: _i(j['reel_id']),
    creatorName: _s(j['creator_name']),
    creatorPicture: _s(j['creator_picture']),
    place: _s(j['place']),
    district: _s(j['district']),
    mediaUrl: _s(j['media_url']),
    mediaType: _s(j['media_type']).toLowerCase(),
    caption: _s(j['caption']),
    createdAt: _s(j['created_at']),
    isLiked: j['is_liked'] == true,
    likesCount: _i(j['likes_count']),
    commentsCount: _i(j['comments_count']),
  );

  String get location => [place, district].where((e) => e.isNotEmpty).join(', ');
}

class SavedReelsPage extends StatefulWidget {
  const SavedReelsPage({Key? key}) : super(key: key);

  @override
  State<SavedReelsPage> createState() => _SavedReelsPageState();
}

class _SavedReelsPageState extends State<SavedReelsPage> {
  List<_SavedReel> _savedReels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSavedReels();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // Fetch Saved Reels
  Future<void> _fetchSavedReels({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final s = await _Session.load();
      if (s.lid.isEmpty || s.url.isEmpty) throw Exception('Session missing');

      final uri = Uri.parse('${s.url}/myapp/user_view_saved_reels/')
          .replace(queryParameters: {'lid': s.lid});

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') {
        throw Exception(data['message'] ?? 'Failed to load saved reels');
      }

      final list = (data['data'] as List)
          .map((e) => _SavedReel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _savedReels = list;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load saved reels. Check your connection.';
        _loading = false;
      });
    }
  }

  // Unsave Reel (Removes reel from UI list)
  Future<void> _removeSavedReel(int index, _SavedReel r) async {
    try {
      final s = await _Session.load();
      final uri = Uri.parse('${s.url}/myapp/user_toggle_save_reel/');

      final res = await http.post(uri, body: {
        'lid': s.lid,
        'reel_id': r.reelId.toString(),
      }).timeout(const Duration(seconds: 15));

      final data = json.decode(res.body) as Map<String, dynamic>;

      if (data['status'] == 'ok') {
        setState(() {
          _savedReels.removeAt(index);
        });
        _snack('Removed from Saved');
      } else {
        _snack(_s(data['message']));
      }
    } catch (_) {
      _snack('Network error. Could not remove reel.');
    }
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
          'Saved Reels',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: _buildBody(),
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
                onPressed: _fetchSavedReels,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () => _fetchSavedReels(showSpinner: false),
      child: _savedReels.isEmpty
          ? ListView(
        children: const [
          SizedBox(
            height: 380,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 64, color: _C.lilac),
                  SizedBox(height: 12),
                  Text(
                    'No saved reels yet.',
                    style: TextStyle(color: _C.muted, fontSize: 15),
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
        itemCount: _savedReels.length,
        itemBuilder: (context, index) {
          final r = _savedReels[index];
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
                // Creator Header
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
                      IconButton(
                        icon: const Icon(Icons.bookmark_rounded, color: _C.sun, size: 28),
                        onPressed: () => _removeSavedReel(index, r),
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
                      Text(r.createdAt,
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