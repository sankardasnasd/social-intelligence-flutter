import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Colours
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

const _videoExt = ['mp4', 'mkv', 'avi', 'mov'];
const _imageExt = ['jpg', 'jpeg', 'png'];
const _audioExt = ['mp3', 'wav'];

class UploadReelPage extends StatefulWidget {
  const UploadReelPage({Key? key}) : super(key: key);

  @override
  State<UploadReelPage> createState() => _UploadReelPageState();
}

class _UploadReelPageState extends State<UploadReelPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  File? _selectedFile;
  bool _isLoading = false;
  bool _fetchingLocation = false;
  int _step = 0;
  Timer? _timer;

  double? _latitude;
  double? _longitude;

  static const _steps = [
    'Uploading your reel...',
    'Reading audio and text...',
    'Checking for unsafe content...',
    'Finding topic and trend...',
    'Predicting reach...',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  // ---------------- Helpers ----------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  String get _fileName =>
      _selectedFile == null ? '' : _selectedFile!.path.split(Platform.pathSeparator).last;

  String get _mediaType {
    if (_selectedFile == null) return '';
    final ext = _selectedFile!.path.split('.').last.toLowerCase();
    if (_videoExt.contains(ext)) return 'video';
    if (_imageExt.contains(ext)) return 'image';
    if (_audioExt.contains(ext)) return 'audio';
    return 'file';
  }

  String get _fileSize {
    if (_selectedFile == null) return '';
    final bytes = _selectedFile!.lengthSync();
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---------------- Location & Reverse Geocoding ----------------
  Future<void> _fetchCurrentLocation() async {
    setState(() => _fetchingLocation = true);

    try {
      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _fetchingLocation = false);
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          setState(() => _fetchingLocation = false);
          return;
        }
      }

      LocationData locationData = await location.getLocation();
      _latitude = locationData.latitude;
      _longitude = locationData.longitude;

      if (_latitude != null && _longitude != null) {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
          _latitude!,
          _longitude!,
        );

        if (placemarks.isNotEmpty) {
          geo.Placemark place = placemarks.first;

          String detectedPlace = '';
          if (place.subLocality != null && place.subLocality!.trim().isNotEmpty) {
            detectedPlace = place.subLocality!.trim();
          } else if (place.locality != null && place.locality!.trim().isNotEmpty) {
            detectedPlace = place.locality!.trim();
          } else if (place.street != null && place.street!.trim().isNotEmpty) {
            detectedPlace = place.street!.trim();
          } else {
            detectedPlace = place.name ?? '';
          }

          String detectedDistrict = '';
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.trim().isNotEmpty) {
            detectedDistrict = place.subAdministrativeArea!.trim();
          } else if (place.locality != null && place.locality!.trim().isNotEmpty && place.locality != detectedPlace) {
            detectedDistrict = place.locality!.trim();
          }

          detectedDistrict = detectedDistrict.replaceAll(RegExp(r'\s+District', caseSensitive: false), '').trim();

          setState(() {
            _placeController.text = detectedPlace;
            _districtController.text = detectedDistrict;
          });
        }
      }
    } catch (e) {
      _snack('Could not fetch location: $e');
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
  }

  // ---------------- File Picker ----------------
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'jpg', 'jpeg', 'png', 'mp3', 'wav'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _snack('File selection error: $e');
    }
  }

  // ---------------- Pre-check & Automatic Upload Flow ----------------
  Future<void> _handleUploadInitiation() async {
    if (_selectedFile == null) {
      _snack('Please select a media file first');
      return;
    }

    setState(() {
      _isLoading = true;
      _step = 0;
    });

    final sh = await SharedPreferences.getInstance();
    var baseUrl = (sh.get('url')?.toString() ?? '').trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    if (baseUrl.isEmpty) {
      setState(() => _isLoading = false);
      _snack('Server URL missing. Please login again.');
      return;
    }

    try {
      // 1. Call Pre-check API for Instant Viral Estimation
      final preCheckUri = Uri.parse('$baseUrl/myapp/precheck_reel_virality/');
      var preCheckReq = http.MultipartRequest('POST', preCheckUri);
      preCheckReq.fields['caption'] = _captionController.text.trim();
      preCheckReq.fields['region'] = _districtController.text.trim().isNotEmpty
          ? _districtController.text.trim()
          : 'Kerala';

      preCheckReq.files.add(
        await http.MultipartFile.fromPath('media_file', _selectedFile!.path),
      );

      var streamedPreCheck = await preCheckReq.send().timeout(const Duration(seconds: 40));
      var preCheckResponse = await http.Response.fromStream(streamedPreCheck);
      final preCheckData = json.decode(preCheckResponse.body);

      setState(() => _isLoading = false);

      if (preCheckData['status'] == 'ok') {
        // 2. Open Viral Prediction Modal with 4-second Countdown
        _showViralPreviewDialog(
          viralPercentage: preCheckData['viral_percentage'] ?? 50,
          topic: preCheckData['core_topic'] ?? 'General Content',
          reach: preCheckData['estimated_reach'] ?? 1000,
          bestTime: preCheckData['recommended_time'] ?? '07:00 PM',
        );
      } else {
        // Fallback: Proceed directly to upload if pre-check fails
        _executeActualUpload();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Fallback: Proceed directly if pre-check network times out
      _executeActualUpload();
    }
  }

  void _showViralPreviewDialog({
    required int viralPercentage,
    required String topic,
    required int reach,
    required String bestTime,
  }) {
    int countdown = 4;
    Timer? countdownTimer;
    bool cancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (tm) {
              if (countdown > 1) {
                setModalState(() => countdown--);
              } else {
                tm.cancel();
                if (!cancelled) {
                  Navigator.of(dialogCtx).pop();
                  _executeActualUpload();
                }
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 16,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AI Virality Potential',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$viralPercentage%',
                      style: const TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: -1.5,
                      ),
                    ),
                    const Text(
                      'VIRAL PROBABILITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _modalInfoRow('Detected Topic', topic),
                          const Divider(height: 14, color: _C.line),
                          _modalInfoRow('Est. Audience Reach', '$reach users'),
                          const Divider(height: 14, color: _C.line),
                          _modalInfoRow('Best Posting Time', bestTime),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13.5, color: _C.muted),
                        children: [
                          const TextSpan(text: 'Posting automatically in '),
                          TextSpan(
                            text: '$countdown',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const TextSpan(text: ' seconds...'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFE2E8F0),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              cancelled = true;
                              countdownTimer?.cancel();
                              Navigator.of(dialogCtx).pop();
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.of(dialogCtx).pop();
                              _executeActualUpload();
                            },
                            child: const Text(
                              'Post Now',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _C.muted, fontWeight: FontWeight.w600)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _C.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ---------------- Final Upload Execution ----------------
  Future<void> _executeActualUpload() async {
    setState(() {
      _isLoading = true;
      _step = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && _step < _steps.length - 1) {
        setState(() => _step++);
      }
    });

    try {
      final sh = await SharedPreferences.getInstance();
      final lid = (sh.get('lid')?.toString() ?? '').trim();
      var baseUrl = (sh.get('url')?.toString() ?? '').trim();
      while (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_upload_reel/');

      var request = http.MultipartRequest('POST', url);
      request.fields['lid'] = lid;
      request.fields['caption'] = _captionController.text.trim();
      request.fields['place'] = _placeController.text.trim();
      request.fields['district'] = _districtController.text.trim();
      request.fields['region'] = _districtController.text.trim().isNotEmpty
          ? _districtController.text.trim()
          : 'Kerala';

      if (_latitude != null) request.fields['latitude'] = _latitude.toString();
      if (_longitude != null) request.fields['longitude'] = _longitude.toString();

      request.files.add(
        await http.MultipartFile.fromPath('media_file', _selectedFile!.path),
      );

      var streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (data['status'] == 'ok') {
        _snack('Reel posted successfully and is now Live!');
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack(data['message']?.toString() ?? 'Upload failed');
      }
    } on FormatException {
      _snack('Server returned an unexpected response format.');
    } catch (e) {
      _snack('Network Error: $e');
    } finally {
      _timer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _captionController.dispose();
    _placeController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Text(
          'Upload reel',
          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reveal(
                  delay: 0,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 18, left: 2),
                    child: Text(
                      'Pick a video, image or audio file. Location is auto-detected via GPS for regional categorization.',
                      style: TextStyle(color: _C.muted, fontSize: 14.5, height: 1.5),
                    ),
                  ),
                ),

                // Media picker / preview
                _Reveal(
                  delay: 80,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(anim), child: child),
                    ),
                    child: hasFile
                        ? _MediaPreview(
                      key: ValueKey(_selectedFile!.path),
                      file: _selectedFile!,
                      type: _mediaType,
                      name: _fileName,
                      size: _fileSize,
                      onChange: _pickFile,
                      onRemove: () => setState(() => _selectedFile = null),
                    )
                        : _DropZone(key: const ValueKey('drop'), onTap: _pickFile),
                  ),
                ),
                const SizedBox(height: 22),

                // Caption Field
                _Reveal(
                  delay: 160,
                  child: _field(
                    controller: _captionController,
                    label: 'Caption / Description',
                    hint: 'Add hashtags, descriptions...',
                    icon: Icons.edit_note_rounded,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),

                // Place & District Fields
                _Reveal(
                  delay: 220,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(
                              controller: _placeController,
                              label: 'Place',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _districtController,
                              label: 'District',
                              icon: Icons.map_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
                          icon: _fetchingLocation
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue),
                          )
                              : const Icon(Icons.my_location_rounded, size: 16, color: _C.blue),
                          label: Text(
                            _fetchingLocation ? 'Locating...' : 'Refresh GPS Location',
                            style: const TextStyle(fontSize: 12.5, color: _C.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Safety note
                _Reveal(
                  delay: 280,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9FAF3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBDEBDA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF1F8F6F), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI will analyze virality before uploading. All valid creative reels are approved and published live.',
                            style: TextStyle(color: Color(0xFF1F6B55), fontSize: 13, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Upload button triggering preview flow
                _Reveal(
                  delay: 340,
                  child: _UploadButton(
                    enabled: hasFile && !_isLoading,
                    onTap: _handleUploadInitiation,
                  ),
                ),
              ],
            ),
          ),

          // Analysis overlay during network operations
          if (_isLoading) _AnalysisOverlay(message: _steps[_step], step: _step, total: _steps.length),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _C.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _C.muted),
        hintStyle: const TextStyle(color: Color(0xFFA0A9C4)),
        floatingLabelStyle: const TextStyle(color: _C.blue, fontWeight: FontWeight.w600),
        prefixIcon: maxLines == 1 ? Icon(icon, color: _C.muted) : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: border(_C.line),
        focusedBorder: border(_C.blue, 1.6),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Entrance Animation
// ---------------------------------------------------------------
class _Reveal extends StatelessWidget {
  final int delay;
  final Widget child;
  const _Reveal({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------
// DropZone
// ---------------------------------------------------------------
class _DropZone extends StatelessWidget {
  final VoidCallback onTap;
  const _DropZone({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorder(color: _C.blue.withOpacity(.55), radius: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF0FF), Color(0xFFF1EBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            children: [
              _PulseIcon(),
              SizedBox(height: 16),
              Text(
                'Tap to choose a file',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.ink),
              ),
              SizedBox(height: 4),
              Text(
                'Select Video / Image / Audio',
                style: TextStyle(fontSize: 13, color: _C.muted),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _TypeChip(icon: Icons.videocam_rounded, label: 'MP4, MOV, MKV, AVI'),
                  _TypeChip(icon: Icons.image_rounded, label: 'JPG, PNG'),
                  _TypeChip(icon: Icons.graphic_eq_rounded, label: 'MP3, WAV'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TypeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _C.blue),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, color: _C.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon();

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 76 + 22 * t,
              height: 76 + 22 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.blue.withOpacity(.14 * (1 - t)),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [_C.blue, _C.lilac],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: Color(0x555F85FF), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => old.color != color || old.radius != radius;
}

// ---------------------------------------------------------------
// Media Preview
// ---------------------------------------------------------------
class _MediaPreview extends StatelessWidget {
  final File file;
  final String type;
  final String name;
  final String size;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _MediaPreview({
    Key? key,
    required this.file,
    required this.type,
    required this.name,
    required this.size,
    required this.onChange,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    List<Color> colors;
    switch (type) {
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF36498C).withOpacity(.10),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (type == 'image')
                    Image.file(file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEEF2FF)))
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Icon(icon, size: 72, color: Colors.white.withOpacity(.95)),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.92),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(type.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800, color: _C.blue)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withOpacity(.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close_rounded, size: 20, color: _C.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: _C.mint, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14, color: _C.ink)),
                      Text(size, style: const TextStyle(fontSize: 12, color: _C.muted)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onChange,
                  child: const Text('Change', style: TextStyle(color: _C.blue, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Upload Button
// ---------------------------------------------------------------
class _UploadButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _UploadButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1 : .5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [_C.blue, Color(0xFF8F7BFF)]),
              boxShadow: enabled
                  ? const [BoxShadow(color: Color(0x665F85FF), blurRadius: 20, offset: Offset(0, 10))]
                  : null,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Upload and run AI analysis',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Analysis Overlay
// ---------------------------------------------------------------
class _AnalysisOverlay extends StatelessWidget {
  final String message;
  final int step;
  final int total;
  const _AnalysisOverlay({required this.message, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: _C.ink.withOpacity(.5),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(strokeWidth: 5, color: _C.blue),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(message,
                    key: ValueKey(message),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.ink)),
              ),
              const SizedBox(height: 6),
              const Text('Please keep the app open',
                  style: TextStyle(fontSize: 12.5, color: _C.muted)),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(total, (i) {
                  final done = i <= step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: done ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done ? _C.blue : _C.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}