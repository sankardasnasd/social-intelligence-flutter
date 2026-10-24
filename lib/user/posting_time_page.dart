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
  static const peach = Color(0xFFFFAB91);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

class PostingTimePage extends StatefulWidget {
  const PostingTimePage({Key? key}) : super(key: key);

  @override
  State<PostingTimePage> createState() => _PostingTimePageState();
}

class _PostingTimePageState extends State<PostingTimePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _timingData;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedTime();
  }

  Future<void> _fetchRecommendedTime() async {
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
          _errorMessage = 'Session expired or Server URL missing. Please log in again.';
        });
        return;
      }

      final uri = Uri.parse('$baseUrl/myapp/user_view_recommended_posting_time/?lid=$lid');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final resJson = json.decode(response.body);
        if (resJson['status'] == 'ok') {
          setState(() {
            _timingData = resJson;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = resJson['message'] ?? 'Failed to load timing analytics.';
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
          'Best Posting Time',
          style: TextStyle(
            color: _C.ink,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.blue),
            tooltip: 'Refresh',
            onPressed: _fetchRecommendedTime,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: _C.blue),
            SizedBox(height: 16),
            Text(
              'Analyzing Regional Peak Activity...',
              style: TextStyle(color: _C.muted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: _fetchRecommendedTime,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _timingData!;
    final List<dynamic> optimalWindows = data['optimal_windows'] ?? [];
    final List<dynamic> hourlyActivity = data['hourly_activity'] ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Best Posting Slot Card
          _buildHeroSlotCard(data),
          const SizedBox(height: 18),

          // 2. Prime Engagement Windows List
          _buildWindowsCard(optimalWindows),
          const SizedBox(height: 18),

          // 3. 24-Hour Regional Audience Curve
          _buildHourlyCurveCard(hourlyActivity, data['region'] ?? 'Kerala'),
        ],
      ),
    );
  }

  // ---------------- 1. Hero Slot Card ----------------
  Widget _buildHeroSlotCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.blue, Color(0xFF8F7BFF), _C.mint],
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Region: ${data['region']}',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Top Day: ${data['peak_day']}',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Recommended Post Slot',
            style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            data['best_posting_time'] ?? '07:00 PM',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(
            data['best_posting_date'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            data['summary'] ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  // ---------------- 2. Optimal Windows ----------------
  Widget _buildWindowsCard(List<dynamic> windows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0836498C),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: _C.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'High-Velocity Engagement Windows',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < windows.length; i++) ...[
            _windowTile(windows[i] as Map<String, dynamic>, i == 0),
            if (i != windows.length - 1) const Divider(height: 16, color: _C.line),
          ],
        ],
      ),
    );
  }

  Widget _windowTile(Map<String, dynamic> win, bool isPrime) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isPrime ? _C.mintBg : _C.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.access_time_filled_rounded,
            color: isPrime ? _C.mint : _C.blueD,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                win['time_range'] ?? '',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _C.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${win['tier']} • ${win['expected_boost']}',
                style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPrime ? _C.mintBg : _C.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            win['activity_percentage'] ?? '0%',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isPrime ? const Color(0xFF15803D) : _C.blueD,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- 3. Hourly Activity Heatmap Curve ----------------
  Widget _buildHourlyCurveCard(List<dynamic> hourly, String region) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '24-Hour Regional Activity Density',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink),
              ),
              Text(
                region,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.blueD),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Audience presence percentage throughout the day',
            style: TextStyle(fontSize: 12.5, color: _C.muted),
          ),
          const SizedBox(height: 18),

          // Horizontal scrollable activity bars
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: hourly.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = hourly[index];
                final double ratio = (item['activity_ratio'] as num?)?.toDouble() ?? 0.1;
                final bool isPeak = ratio >= 0.85;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(ratio * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isPeak ? _C.mint : _C.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 22,
                      height: (ratio * 55).clamp(8.0, 55.0),
                      decoration: BoxDecoration(
                        color: isPeak ? _C.mint : _C.blue.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['label'] ?? '',
                      style: const TextStyle(fontSize: 10, color: _C.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}