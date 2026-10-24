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
  static const mintBg = Color(0xFFE9FAF3);
  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0xFFFEF3C7);
  static const red = Color(0xFFEF4444);
}

class ReachPredictionPage extends StatefulWidget {
  const ReachPredictionPage({Key? key}) : super(key: key);

  @override
  State<ReachPredictionPage> createState() => _ReachPredictionPageState();
}

class _ReachPredictionPageState extends State<ReachPredictionPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchReachAnalytics();
  }

  Future<void> _fetchReachAnalytics() async {
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

      if (baseUrl.isEmpty || lid.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session expired or Server URL is missing.';
        });
        return;
      }

      final uri = Uri.parse('$baseUrl/myapp/user_view_predicted_reach_analytics/?lid=$lid');
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
            _errorMessage = resJson['message'] ?? 'Failed to load reach predictions.';
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
        _errorMessage = 'Connection failed: $e';
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
          'Predicted Reach & Engagement',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.blue),
            onPressed: _fetchReachAnalytics,
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
                onPressed: _fetchReachAnalytics,
                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    final overview = _data!['overview'] as Map<String, dynamic>? ?? {};
    final List<dynamic> reels = _data!['reels'] ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Metric Banner
          _buildHeroOverviewCard(overview),
          const SizedBox(height: 22),

          const Text(
            'Reel-by-Reel Reach Forecasts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
          ),
          const SizedBox(height: 12),

          if (reels.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line),
              ),
              child: const Center(
                child: Text('No uploaded reels to predict reach.', style: TextStyle(color: _C.muted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildReelReachCard(reels[index] as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroOverviewCard(Map<String, dynamic> ov) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [_C.blue, _C.blueD, Color(0xFF8F7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumulative Audience Reach',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${ov['total_cumulative_reach'] ?? 0}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _heroMetricItem('Avg Reel Reach', '${ov['average_reach_per_reel'] ?? 0}'),
              ),
              Expanded(
                child: _heroMetricItem('Viral Potential', '${ov['high_potential_count'] ?? 0} High'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetricItem(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildReelReachCard(Map<String, dynamic> r) {
    final String level = r['expected_level']?.toString() ?? 'Medium';
    final isHigh = level.toLowerCase() == 'high';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isHigh ? _C.mintBg : _C.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: isHigh ? _C.mint : _C.blueD,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['core_topic'] ?? 'General',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r['created_at']} • ${r['social_impact_level']} Impact',
                  style: const TextStyle(fontSize: 11.5, color: _C.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${r['predicted_reach']} reach',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${r['engagement_rate']} rate',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isHigh ? _C.mint : _C.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}