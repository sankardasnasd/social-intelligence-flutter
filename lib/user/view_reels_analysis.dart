import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

// Modern SaaS Theme Colors
class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const blueD = Color(0xFF4569E0);
  static const mint = Color(0xFF10B981);
  static const mintBg = Color(0xFFE9FAF3);
  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0xFFFEF3C7);
}

class ViewReelAnalysisPage extends StatefulWidget {
  const ViewReelAnalysisPage({Key? key}) : super(key: key);

  @override
  State<ViewReelAnalysisPage> createState() => _ViewReelAnalysisPageState();
}

class _ViewReelAnalysisPageState extends State<ViewReelAnalysisPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _reelsList = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllReelsAnalysis();
  }

  // ---------------- Fetch Data from Django Backend ----------------
  Future<void> _fetchAllReelsAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sh = await SharedPreferences.getInstance();
      final lid = (sh.get('lid')?.toString() ?? '').trim();
      var baseUrl = (sh.get('url')?.toString() ?? '').trim();

      // Clean trailing slashes safely
      while (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      if (baseUrl.isEmpty || lid.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Session expired or Server URL is missing. Please log in again.';
        });
        return;
      }

      final uri = Uri.parse('$baseUrl/myapp/user_view_all_reels_analysis/?lid=$lid');
      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resJson = json.decode(response.body);
        if (resJson['status'] == 'ok') {
          final List<dynamic> reels = resJson['reels'] ?? [];
          setState(() {
            _reelsList = reels;
            _selectedIndex = 0; // Default to latest reel
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = resJson['message'] ?? 'Unable to retrieve analysis details.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server responded with status: ${response.statusCode}';
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
          'Reel AI Analytics',
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
            onPressed: _fetchAllReelsAnalysis,
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
              'Running AI Multimodal Analysis...',
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
              const Icon(Icons.error_outline_rounded, color: _C.red, size: 50),
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
                onPressed: _fetchAllReelsAnalysis,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_reelsList.isEmpty) {
      return const Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined, size: 56, color: _C.muted),
              SizedBox(height: 14),
              Text(
                'No uploaded reels found.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.ink),
              ),
              SizedBox(height: 6),
              Text(
                'Upload a video or photo reel to generate AI virality predictions and safety reports.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: _C.muted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final data = _reelsList[_selectedIndex] as Map<String, dynamic>;
    final virality = data['virality_analysis'] as Map<String, dynamic>? ?? {};

    final String viralPctStr = virality['viral_probability']?.toString() ?? '50%';
    final int viralScore = virality['viral_score_num'] is int
        ? virality['viral_score_num']
        : (int.tryParse(viralPctStr.replaceAll('%', '').trim()) ?? 50);

    final String mediaUrl = data['media_url']?.toString() ?? '';
    final String mediaType = (data['media_type']?.toString() ?? 'video').toLowerCase();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Horizontal Switcher for Uploaded Reels (Latest First)
          if (_reelsList.length > 1) ...[
            _buildReelHorizontalPicker(),
            const SizedBox(height: 16),
          ],

          // 2. VIDEO PLAYER / MEDIA DISPLAY CARD (Latest on top)
          _buildActiveVideoPlayerCard(mediaUrl, mediaType, data),
          const SizedBox(height: 18),

          // 3. Virality & Reach Hero Card
          _buildViralityCard(viralPctStr, viralScore, virality),
          const SizedBox(height: 16),

          // 4. Extracted Topic & Categorization
          _buildDetailsCard(data),
          const SizedBox(height: 16),

          // 5. Sentiment & Safety Guard Status
          _buildSafetyAndSentimentCard(data),
          const SizedBox(height: 16),

          // 6. Multimodal Signals (Whisper Audio & Frame OCR)
          _buildSignalsCard(data),
        ],
      ),
    );
  }

  // ---------------- Horizontal Reel Thumbnail Switcher ----------------
  Widget _buildReelHorizontalPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Your Uploaded Reels (Latest First)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.muted),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _reelsList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              final item = _reelsList[index];
              final String topic = item['core_topic']?.toString() ?? 'General';
              final String date = item['created_at']?.toString() ?? '';

              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _C.blueD : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _C.blueD : _C.line,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? _C.blueD.withOpacity(0.24) : const Color(0x0836498C),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            index == 0 ? Icons.fiber_new_rounded : Icons.play_circle_fill_rounded,
                            size: 16,
                            color: isSelected ? Colors.white : _C.blueD,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              topic,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : _C.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white.withOpacity(0.85) : _C.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------- 2. Video Player & Media View Card ----------------
  Widget _buildActiveVideoPlayerCard(String url, String mediaType, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C36498C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Media Player Area
          SizedBox(
            height: 340,
            width: double.infinity,
            child: _ReelPlayerWidget(
              key: ValueKey(url),
              mediaUrl: url,
              mediaType: mediaType,
            ),
          ),

          // Caption & Media Info Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Reel #${data['reel_id']}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _C.blueD,
                        ),
                      ),
                    ),
                    Text(
                      data['created_at']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if ((data['caption']?.toString().trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  Text(
                    data['caption']!.toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _C.ink,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 3. Virality Potential Card ----------------
  Widget _buildViralityCard(String viralPctStr, int viralScore, Map<String, dynamic> virality) {
    Color badgeColor = _C.mint;
    Color badgeBg = _C.mintBg;
    String statusText = 'High Potential';

    if (viralScore < 50) {
      badgeColor = _C.red;
      badgeBg = _C.redBg;
      statusText = 'Niche Reach';
    } else if (viralScore < 75) {
      badgeColor = const Color(0xFFB45309);
      badgeBg = _C.amberBg;
      statusText = 'Moderate';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C36498C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Virality Potential',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _C.ink),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            viralPctStr,
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              color: _C.mint,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            virality['verdict']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _C.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _C.line),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _kpiBox(
                  icon: Icons.people_outline_rounded,
                  label: 'Predicted Reach',
                  value: '${virality['predicted_reach'] ?? 0} users',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiBox(
                  icon: Icons.access_time_rounded,
                  label: 'Peak Posting Time',
                  value: virality['recommended_posting_time']?.toString() ?? '07:00 PM',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: _C.blueD),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11.5, color: _C.muted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _C.ink, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ---------------- 4. Core Topic & Info ----------------
  Widget _buildDetailsCard(Map<String, dynamic> data) {
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
          const Text('Content Classification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 14),
          _detailRow('Detected Topic', data['core_topic']?.toString() ?? 'General', isTopic: true),
          const Divider(height: 18, color: _C.line),
          _detailRow('Category', data['category']?.toString() ?? 'Entertainment'),
          const Divider(height: 18, color: _C.line),
          _detailRow('Media Type', (data['media_type']?.toString() ?? 'video').toUpperCase()),
          const Divider(height: 18, color: _C.line),
          _detailRow('Uploaded Date', data['created_at']?.toString() ?? ''),
          const Divider(height: 18, color: _C.line),
          _detailRow('Restriction Status', (data['restriction_status']?.toString() ?? 'approved').toUpperCase()),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isTopic = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isTopic ? _C.blueD : _C.ink,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- 5. Safety & Sentiment Card ----------------
  Widget _buildSafetyAndSentimentCard(Map<String, dynamic> data) {
    final String sentiment = data['sentiment']?.toString().toLowerCase() ?? 'neutral';
    final String riskLevel = data['risk_level']?.toString().toLowerCase() ?? 'low';

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
          const Text('Sentiment & Safety Guard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statusBadgeBox(
                  title: 'Sentiment',
                  label: sentiment.toUpperCase(),
                  color: sentiment == 'positive' ? _C.mint : (sentiment == 'negative' ? _C.red : _C.blue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statusBadgeBox(
                  title: 'Safety Risk',
                  label: riskLevel.toUpperCase(),
                  color: riskLevel == 'low' ? _C.mint : (riskLevel == 'medium' ? _C.amber : _C.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadgeBox({required String title, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ---------------- 6. Audio & Text Extracted Signals ----------------
  Widget _buildSignalsCard(Map<String, dynamic> data) {
    final String transcript = data['transcript']?.toString() ?? '';
    final String ocrText = data['extracted_ocr']?.toString() ?? '';

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
          const Text('Extracted Multimodal Signals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 14),
          _signalBlock(
            icon: Icons.mic_rounded,
            title: 'Whisper Speech-to-Text',
            content: transcript.isNotEmpty ? transcript : 'No speech detected in audio.',
          ),
          const SizedBox(height: 12),
          _signalBlock(
            icon: Icons.document_scanner_outlined,
            title: 'Computer Vision OCR Text',
            content: ocrText.isNotEmpty ? ocrText : 'No visible text detected on video frames.',
          ),
        ],
      ),
    );
  }

  Widget _signalBlock({required IconData icon, required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _C.blueD),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, color: _C.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMBEDDED MEDIA/VIDEO PLAYER COMPONENT
// ============================================================

class _ReelPlayerWidget extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;

  const _ReelPlayerWidget({
    Key? key,
    required this.mediaUrl,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<_ReelPlayerWidget> createState() => _ReelPlayerWidgetState();
}

class _ReelPlayerWidgetState extends State<_ReelPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isInit = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video' && widget.mediaUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      if (mounted) {
        setState(() {
          _isInit = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType == 'image') {
      return Container(
        color: Colors.black,
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.white54),
          ),
        ),
      );
    }

    if (widget.mediaType == 'audio') {
      return Container(
        color: const Color(0xFF1E293B),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 60, color: _C.mint),
            SizedBox(height: 12),
            Text(
              'Audio Track Reel',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Video Handling
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_disabled_rounded, size: 40, color: Colors.white54),
              SizedBox(height: 8),
              Text(
                'Unable to stream video',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInit || _videoController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: _C.blue, strokeWidth: 2.5),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _videoController!.value.isPlaying
              ? _videoController!.pause()
              : _videoController!.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio > 0
                    ? _videoController!.value.aspectRatio
                    : (9 / 16),
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
          if (!_videoController!.value.isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 46,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}