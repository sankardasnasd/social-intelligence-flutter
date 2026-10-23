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

class _SharedReelItem {
  final int shareId;
  final String userName;
  final String userPicture;
  final int reelId;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final String sharedAt;

  _SharedReelItem({
    required this.shareId,
    required this.userName,
    required this.userPicture,
    required this.reelId,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.sharedAt,
  });

  factory _SharedReelItem.fromJson(Map<String, dynamic> j) => _SharedReelItem(
    shareId: j['share_id'] is int ? j['share_id'] : int.tryParse(_s(j['share_id'])) ?? 0,
    userName: _s(j['user_name']),
    userPicture: _s(j['user_picture']),
    reelId: j['reel_id'] is int ? j['reel_id'] : int.tryParse(_s(j['reel_id'])) ?? 0,
    mediaUrl: _s(j['media_url']),
    mediaType: _s(j['media_type']).toLowerCase(),
    caption: _s(j['caption']),
    sharedAt: _s(j['shared_at']),
  );
}

class SharedReelsHubPage extends StatefulWidget {
  const SharedReelsHubPage({Key? key}) : super(key: key);

  @override
  State<SharedReelsHubPage> createState() => _SharedReelsHubPageState();
}

class _SharedReelsHubPageState extends State<SharedReelsHubPage> {
  String _activeTab = 'received'; // 'received' or 'sent'
  List<_SharedReelItem> _reels = [];
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

      final uri = Uri.parse('${s.url}/myapp/user_view_shared_reels_hub/')
          .replace(queryParameters: {'lid': s.lid, 'type': _activeTab});

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'ok') {
        throw Exception(data['message'] ?? 'Failed to load reels');
      }

      final list = (data['data'] as List)
          .map((e) => _SharedReelItem.fromJson(e as Map<String, dynamic>))
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
        _error = 'Could not load reels. Please try again.';
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
          'Shared Reels',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
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
                      title: 'Received',
                      icon: Icons.call_received_rounded,
                      isActive: _activeTab == 'received',
                      onTap: () => _switchTab('received'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TabButton(
                      title: 'Sent',
                      icon: Icons.call_made_rounded,
                      isActive: _activeTab == 'sent',
                      onTap: () => _switchTab('sent'),
                    ),
                  ),
                ],
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
                    _activeTab == 'received'
                        ? Icons.mark_chat_unread_outlined
                        : Icons.send_outlined,
                    size: 60,
                    color: _C.lilac,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activeTab == 'received'
                        ? 'No reels received from friends.'
                        : 'You have not sent any reels to friends.',
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
          final item = _reels[index];
          return _SharedReelCard(
            item: item,
            isSent: _activeTab == 'sent',
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

class _SharedReelCard extends StatelessWidget {
  final _SharedReelItem item;
  final bool isSent;

  const _SharedReelCard({required this.item, required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF36498C).withOpacity(.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(name: item.userName, url: item.userPicture, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14, color: _C.ink),
                          children: [
                            TextSpan(
                              text: isSent ? 'Sent to ' : 'Shared by ',
                              style: const TextStyle(color: _C.muted),
                            ),
                            TextSpan(
                              text: item.userName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (item.sharedAt.isNotEmpty)
                        Text(
                          item.sharedAt,
                          style: const TextStyle(fontSize: 11.5, color: _C.muted),
                        ),
                    ],
                  ),
                ),
                Icon(
                  isSent ? Icons.call_made_rounded : Icons.call_received_rounded,
                  color: isSent ? Colors.orange : _C.blue,
                  size: 20,
                ),
              ],
            ),
          ),

          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 240,
              width: double.infinity,
              color: Colors.black12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.mediaType == 'image' && item.mediaUrl.isNotEmpty)
                    Image.network(
                      item.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 48, color: _C.muted),
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
                            item.mediaType == 'video'
                                ? Icons.play_circle_fill_rounded
                                : Icons.graphic_eq_rounded,
                            size: 64,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.mediaType == 'video' ? 'Video Reel' : 'Audio Reel',
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

          if (item.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                item.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: _C.ink),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
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