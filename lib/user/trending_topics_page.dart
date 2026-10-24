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
  static const blueD = Color(0xFF4569E0);
  static const mint = Color(0xFF10B981);
  static const peach = Color(0xFFFFAB91);
  static const red = Color(0xFFEF4444);
}

class TrendingTopicsPage extends StatefulWidget {
  const TrendingTopicsPage({Key? key}) : super(key: key);

  @override
  State<TrendingTopicsPage> createState() => _TrendingTopicsPageState();
}

class _TrendingTopicsPageState extends State<TrendingTopicsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchTrendingData();
  }

  Future<void> _fetchTrendingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sh = await SharedPreferences.getInstance();
      final lid = (sh.get('lid')?.toString() ?? '').trim();
      var baseUrl = (sh.get('url')?.toString() ?? '').trim();

      while (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      if (baseUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server URL missing. Please log in again.';
        });
        return;
      }

      final uri = Uri.parse('$baseUrl/myapp/user_view_trending_topics_analytics/?lid=$lid');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resJson = json.decode(response.body);
        if (resJson['status'] == 'ok') {
          setState(() {
            _data = resJson;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = resJson['message'] ?? 'Failed to load trending topics.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failure: $e';
        _isLoading = false;
      });
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
          'Trending Topics & Reels',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.blue),
            onPressed: _fetchTrendingData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3, color: _C.blue));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: _C.red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _C.blue),
                onPressed: _fetchTrendingData,
                child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    final region = _data!['region'] ?? 'Kerala';
    final List<dynamic> topics = _data!['trending_topics'] ?? [];
    final List<dynamic> reels = _data!['top_trending_reels'] ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Region Strip
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: _C.peach, size: 22),
              const SizedBox(width: 8),
              Text(
                'Top Trends in $region',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Trending Topics Bar List
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              children: [
                if (topics.isEmpty)
                  const Text('No trending topics identified yet.', style: TextStyle(color: _C.muted))
                else
                  for (int i = 0; i < topics.length; i++) ...[
                    _trendTopicRow(topics[i] as Map<String, dynamic>, i + 1),
                    if (i != topics.length - 1) const Divider(height: 18, color: _C.line),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Trending Reels Leaderboard
          const Row(
            children: [
              Icon(Icons.video_library_rounded, color: _C.blueD, size: 20),
              SizedBox(width: 8),
              Text(
                'Viral Reels In Your Region',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (reels.isEmpty)
            const Text('No regional viral reels available.', style: TextStyle(color: _C.muted))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) => _sampleReelTile(reels[idx] as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }

  Widget _trendTopicRow(Map<String, dynamic> t, int rank) {
    final double score = (t['score'] as num?)?.toDouble() ?? 0.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? _C.peach.withOpacity(0.2) : _C.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: rank <= 3 ? const Color(0xFFC2410C) : _C.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  t['topic'] ?? 'Topic',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                ),
              ],
            ),
            Text(
              '${t['frequency_count']} reels',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.clamp(0.05, 1.0),
            minHeight: 6,
            backgroundColor: _C.bg,
            color: rank <= 3 ? _C.peach : _C.blue,
          ),
        ),
      ],
    );
  }

  Widget _sampleReelTile(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: _C.blueD),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['caption'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink),
                ),
                Text(
                  'by ${r['creator']} • ${r['topic']}',
                  style: const TextStyle(fontSize: 11.5, color: _C.muted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 14, color: _C.peach),
              const SizedBox(width: 4),
              Text(
                '${r['likes']}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _C.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}