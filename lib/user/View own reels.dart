import 'dart:async';
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
  static const mint = Color(0xFF5FD3B0);
  static const peach = Color(0xFFFFAB91);
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
class OwnReel {
  final int id;
  final String mediaUrl;
  final String mediaType; // video | image | audio
  final String caption;
  final bool isFlagged;
  final String restrictionStatus; // approved | under_review | restricted
  final String processingStatus; // pending | processing | completed | failed
  final int viewCount;
  final String createdAt;

  OwnReel({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.isFlagged,
    required this.restrictionStatus,
    required this.processingStatus,
    required this.viewCount,
    required this.createdAt,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();
  static int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;

  factory OwnReel.fromJson(Map<String, dynamic> j) => OwnReel(
    id: _i(j['id']),
    mediaUrl: _s(j['media_url']),
    mediaType: _s(j['media_type']).toLowerCase(),
    caption: _s(j['caption']),
    isFlagged: j['is_flagged'] == true,
    restrictionStatus: _s(j['restriction_status']),
    processingStatus: _s(j['processing_status']),
    viewCount: _i(j['view_count']),
    createdAt: _s(j['created_at']),
  );

  bool get isProcessing => processingStatus == 'pending' || processingStatus == 'processing';
  bool get isFailed => processingStatus == 'failed';
  String get shortDate => createdAt.split(' ').first;
}

// ---------------------------------------------------------------
// Screen
// ---------------------------------------------------------------
class ViewOwnReels extends StatefulWidget {
  /// Optional: shown as a button when the user has no reels yet
  final VoidCallback? onUpload;
  const ViewOwnReels({super.key, this.onUpload});

  @override
  State<ViewOwnReels> createState() => _ViewOwnReelsState();
}

class _ViewOwnReelsState extends State<ViewOwnReels> {
  List<OwnReel> _reels = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    _poll?.cancel();
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final s = await _Session.load();
      if (s.lid.isEmpty || s.url.isEmpty) throw Exception('Not signed in');

      final uri = Uri.parse('${s.url}/myapp/user_view_own_reels/')
          .replace(queryParameters: {'lid': s.lid});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'ok') throw Exception(body['message'] ?? 'Could not load reels');

      final list = (body['data'] as List)
          .map((e) => OwnReel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _reels = list;
        _loading = false;
        _error = null;
      });

      // while a reel is still being analysed, check again every few seconds
      if (list.any((r) => r.isProcessing)) {
        _poll = Timer(const Duration(seconds: 6), () {
          if (mounted) _load(showSpinner: false);
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (showSpinner || _reels.isEmpty) {
        setState(() {
          _error = 'Could not load your reels. Check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  List<OwnReel> get _visible =>
      _filter == 'all' ? _reels : _reels.where((r) => r.mediaType == _filter).toList();

  int _count(String type) =>
      type == 'all' ? _reels.length : _reels.where((r) => r.mediaType == type).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Text('My reels',
            style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22)),
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
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }

    final items = _visible;
    final totalViews = _reels.fold<int>(0, (sum, r) => sum + r.viewCount);
    final flagged = _reels.where((r) => r.isFlagged).length;

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: () => _load(showSpinner: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ----- stats -----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                        icon: Icons.video_library_rounded,
                        color: _C.blue,
                        value: _reels.length,
                        label: 'Reels'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                        icon: Icons.visibility_rounded,
                        color: _C.lilac,
                        value: totalViews,
                        label: 'Views'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                        icon: Icons.flag_rounded,
                        color: const Color(0xFFFF7A7A),
                        value: flagged,
                        label: 'Flagged'),
                  ),
                ],
              ),
            ),
          ),

          // ----- filters -----
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in const ['all', 'video', 'image', 'audio'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: f == 'all' ? 'All' : '${f[0].toUpperCase()}${f.substring(1)}s',
                        count: _count(f),
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ----- grid / empty -----
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                icon: Icons.movie_creation_outlined,
                text: _reels.isEmpty
                    ? 'You have not uploaded any reels yet.'
                    : 'No ${_filter}s uploaded yet.',
                action: (_reels.isEmpty && widget.onUpload != null)
                    ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _C.blue),
                  onPressed: widget.onUpload,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Upload your first reel'),
                )
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final r = items[i];
                    final delay = (i < 8 ? i : 8) * 70;
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('${r.id}-$_filter'),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 420 + delay),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.scale(scale: .92 + .08 * v, child: child),
                      ),
                      child: _ReelCard(reel: r, onTap: () => _showDetails(r)),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDetails(OwnReel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, controller) => _DetailSheet(reel: r, controller: controller),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Header widgets
// ---------------------------------------------------------------
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _StatTile(
      {required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF36498C).withOpacity(.07),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(v.round().toString(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.ink)),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: _C.muted)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _C.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _C.blue : _C.line),
        ),
        child: Text('$label  $count',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: selected ? Colors.white : _C.muted)),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Grid card
// ---------------------------------------------------------------
class _ReelCard extends StatelessWidget {
  final OwnReel reel;
  final VoidCallback onTap;
  const _ReelCard({required this.reel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF36498C).withOpacity(.12),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumb(reel: reel),

              // dark gradient at the bottom for readable text
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB31F2A4D), Color(0x001F2A4D)],
                    ),
                  ),
                ),
              ),

              Positioned(top: 10, left: 10, child: _TypeBadge(type: reel.mediaType)),
              Positioned(top: 10, right: 10, child: _StatusBadge(reel: reel)),

              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('${reel.viewCount}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    Text(reel.shortDate,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final OwnReel reel;
  const _Thumb({required this.reel});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    List<Color> colors;
    switch (reel.mediaType) {
      case 'video':
        icon = Icons.play_circle_fill_rounded;
        colors = const [Color(0xFF9DB6FF), Color(0xFFB79CFF)];
        break;
      case 'audio':
        icon = Icons.graphic_eq_rounded;
        colors = const [Color(0xFF5FD3B0), Color(0xFF9DB6FF)];
        break;
      default:
        icon = Icons.image_rounded;
        colors = const [Color(0xFFFFAB91), Color(0xFFFFD27A)];
    }

    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Icon(icon, size: 54, color: Colors.white.withOpacity(.95))),
    );

    if (reel.mediaType == 'image' && reel.mediaUrl.isNotEmpty) {
      return Image.network(
        reel.mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      );
    }
    return fallback;
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = type == 'video'
        ? Icons.videocam_rounded
        : type == 'audio'
        ? Icons.graphic_eq_rounded
        : Icons.image_rounded;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.92), shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: _C.blue),
    );
  }
}

/// Status of a reel: analysing / failed / approved / in review / restricted
class _StatusInfo {
  final String label;
  final Color fg;
  final Color bg;
  final bool spinner;
  const _StatusInfo(this.label, this.fg, this.bg, {this.spinner = false});

  static _StatusInfo of(OwnReel r) {
    if (r.isProcessing) {
      return const _StatusInfo('Analysing', Color(0xFF3F5FD0), Color(0xFFE6EDFF), spinner: true);
    }
    if (r.isFailed) {
      return const _StatusInfo('Failed', Color(0xFFC24B4B), Color(0xFFFFE9E9));
    }
    switch (r.restrictionStatus) {
      case 'restricted':
        return const _StatusInfo('Restricted', Color(0xFFC24B4B), Color(0xFFFFE9E9));
      case 'approved':
        return const _StatusInfo('Approved', Color(0xFF1F8F6F), Color(0xFFE2F8F0));
      default:
        return const _StatusInfo('In review', Color(0xFF9A6B00), Color(0xFFFFF4D6));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final OwnReel reel;
  const _StatusBadge({required this.reel});

  @override
  Widget build(BuildContext context) {
    final s = _StatusInfo.of(reel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.spinner) ...[
            SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(strokeWidth: 2, color: s.fg)),
            const SizedBox(width: 6),
          ],
          Text(s.label,
              style: TextStyle(color: s.fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Details sheet
// ---------------------------------------------------------------
class _DetailSheet extends StatelessWidget {
  final OwnReel reel;
  final ScrollController controller;
  const _DetailSheet({required this.reel, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = _StatusInfo.of(reel);

    String note = '';
    Color noteColor = _C.muted;
    if (reel.isProcessing) {
      note = 'Your reel is being analysed. This page updates by itself when it is done.';
    } else if (reel.isFailed) {
      note = 'The analysis failed. You can try uploading this reel again.';
      noteColor = const Color(0xFFC24B4B);
    } else if (reel.restrictionStatus == 'restricted') {
      note = 'This reel is restricted and may not be shown to other users.';
      noteColor = const Color(0xFFC24B4B);
    } else if (reel.restrictionStatus == 'under_review') {
      note = 'This reel is waiting for review.';
      noteColor = const Color(0xFF9A6B00);
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: _C.line, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(height: 220, width: double.infinity, child: _Thumb(reel: reel)),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: s.label, fg: s.fg, bg: s.bg),
            _Pill(
                label: reel.mediaType.isEmpty
                    ? 'Media'
                    : '${reel.mediaType[0].toUpperCase()}${reel.mediaType.substring(1)}',
                fg: _C.blue,
                bg: const Color(0xFFE9EFFF)),
            if (reel.isFlagged)
              const _Pill(label: 'Flagged', fg: Color(0xFFC24B4B), bg: Color(0xFFFFE9E9)),
          ],
        ),
        const SizedBox(height: 16),
        Text(reel.caption.isEmpty ? 'No caption' : reel.caption,
            style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: reel.caption.isEmpty ? _C.muted : _C.ink,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: _InfoBox(
                    icon: Icons.visibility_rounded,
                    label: 'Views',
                    value: '${reel.viewCount}')),
            const SizedBox(width: 12),
            Expanded(
                child: _InfoBox(
                    icon: Icons.schedule_rounded, label: 'Uploaded', value: reel.createdAt)),
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: noteColor.withOpacity(.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: noteColor),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(note,
                        style: TextStyle(color: noteColor, fontSize: 13.5, height: 1.45))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _C.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _C.muted)),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink)),
              ],
            ),
          ),
        ],
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