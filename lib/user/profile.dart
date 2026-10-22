import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// COLORS  (soft pastel theme)
// ============================================================

class _C {
  static const bg = Color(0xFFF5F7FD);
  static const ink = Color(0xFF1F2A4D);
  static const muted = Color(0xFF5F6B8C);
  static const line = Color(0xFFDDE3F3);
  static const blue = Color(0xFF5F85FF);
  static const blueDark = Color(0xFF4569E0);
  static const violet = Color(0xFF8F7BFF);
  static const mint = Color(0xFF5FD3B0);
  static const lilac = Color(0xFFB79CFF);
  static const peach = Color(0xFFFFAB91);
  static const sun = Color(0xFFFFD27A);
  static const flag = Color(0xFFFF7A7A);
  static const shadow = Color(0xFF36498C);
}

// ============================================================
// MANAGE PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final placeController = TextEditingController();
  final districtController = TextEditingController();
  final regionController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  final Location _location = Location();
  final ImagePicker _picker = ImagePicker();

  File? _newImage;
  String _imageUrl = '';
  String _status = '';

  bool _loading = true;
  String _loadError = '';
  bool _saving = false;
  bool _fetchingLoc = false;

  // ---------------- ANIMATION ----------------
  late final AnimationController _bgCtrl;
  late final AnimationController _blobCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _shineCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    final curve = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);

    // refresh name in the header while typing
    nameController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadProfile();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _floatCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    nameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dobController.dispose();
    placeController.dispose();
    districtController.dispose();
    regionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _s(dynamic v) => v == null ? '' : v.toString();

  String _first(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  void _msg(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(color: _C.ink)),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _C.line),
        ),
      ),
    );
  }

  Future<String> _baseUrl() async {
    final sh = await SharedPreferences.getInstance();
    String base = sh.getString('url') ?? '';
    base = base.replaceFirst(RegExp(r'/$'), '');
    if (base == 'null') base = '';
    return base;
  }

  void _fill(Map<dynamic, dynamic> d) {
    nameController.text = _s(d['name']);
    usernameController.text = _s(d['username']);
    phoneController.text = _s(d['phone']);
    emailController.text = _s(d['email']);
    dobController.text = _s(d['dob']);
    placeController.text = _s(d['place']);
    districtController.text = _s(d['district']);
    regionController.text = _s(d['region']);
    latitudeController.text = _s(d['latitude']);
    longitudeController.text = _s(d['longitude']);
    _imageUrl = _s(d['profile_picture']);
    _status = _s(d['status']);
  }

  // ============================================================
  // VIEW PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });

    try {
      final sh = await SharedPreferences.getInstance();
      final lid = sh.getString('lid') ?? '';
      final base = await _baseUrl();

      if (base.isEmpty) {
        _loadError = 'Server URL not configured';
        return;
      }
      if (lid.isEmpty) {
        _loadError = 'Login ID not found. Please sign in again';
        return;
      }

      final url = Uri.parse('$base/myapp/view_profile/')
          .replace(queryParameters: {'lid': lid});

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      debugPrint('Profile status: ${response.statusCode}');
      debugPrint('Profile response: ${response.body}');

      if (response.statusCode != 200) {
        _loadError = 'Server error: ${response.statusCode}';
        return;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['status'] != 'ok') {
        _loadError = _s(result['message']).isEmpty
            ? 'Profile not found'
            : _s(result['message']);
        return;
      }

      final data = result['data'] as Map<String, dynamic>;
      _fill(data);

      await sh.setString('name', nameController.text);
    } catch (e) {
      debugPrint('Profile load error: $e');
      _loadError = 'Unable to connect. Check the server and try again';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final sh = await SharedPreferences.getInstance();
      final lid = sh.getString('lid') ?? '';
      final base = await _baseUrl();

      if (base.isEmpty) {
        _msg('Server URL not configured.');
        return;
      }
      if (lid.isEmpty) {
        _msg('Login ID not found. Please sign in again.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$base/myapp/update_profile/'),
      );

      request.fields.addAll({
        'lid': lid,
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'dob': dobController.text.trim(),
        'place': placeController.text.trim(),
        'district': districtController.text.trim(),
        'region': regionController.text.trim(),
        'latitude': latitudeController.text.trim(),
        'longitude': longitudeController.text.trim(),
      });

      if (_newImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_picture', _newImage!.path),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      debugPrint('Update status: ${response.statusCode}');
      debugPrint('Update response: ${response.body}');

      if (!mounted) return;

      if (response.statusCode != 200) {
        _msg('Server error: ${response.statusCode}');
        return;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (result['status'] == 'ok') {
        final data = result['data'];
        if (data is Map) {
          setState(() {
            _fill(data);
            _newImage = null;
          });
        }
        await sh.setString('name', nameController.text.trim());
        _msg(_s(result['message']).isEmpty
            ? 'Profile updated successfully'
            : _s(result['message']));
      } else {
        _msg(_s(result['message']).isEmpty
            ? 'Unable to update profile'
            : _s(result['message']));
      }
    } catch (e) {
      debugPrint('Profile update error: $e');
      _msg('Unable to connect. Check the server and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // PICKERS + LOCATION
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _newImage = File(image.path);
        });
      }
    } catch (e) {
      _msg('Unable to select profile picture.');
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();

    DateTime initial = DateTime(now.year - 18, now.month, now.day);
    final parsed = DateTime.tryParse(dobController.text.trim());
    if (parsed != null) initial = parsed;

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected != null && mounted) {
      dobController.text = '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;

    setState(() {
      _fetchingLoc = true;
    });

    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }
      if (!serviceEnabled) {
        _msg('Please enable GPS.');
        return;
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (permission != PermissionStatus.granted) {
        _msg('Please allow location permission.');
        return;
      }

      final gps = await _location.getLocation();
      if (gps.latitude == null || gps.longitude == null) {
        _msg('Unable to get GPS coordinates.');
        return;
      }

      final lat = gps.latitude!;
      final lon = gps.longitude!;

      if (!mounted) return;
      setState(() {
        latitudeController.text = lat.toString();
        longitudeController.text = lon.toString();
      });

      final list = await geo.placemarkFromCoordinates(lat, lon);
      if (list.isEmpty) {
        _msg('Address not found. Enter details manually.');
        return;
      }

      final f = list.first;

      String district = '';
      for (final a in list) {
        district = _first([a.subAdministrativeArea]);
        if (district.isNotEmpty) break;
      }

      final place = _first([
        f.subLocality,
        f.name,
        f.thoroughfare,
        f.locality,
        f.street,
      ]);

      final region = _first(list.map((a) => a.administrativeArea).toList());

      if (!mounted) return;
      setState(() {
        placeController.text = place;
        districtController.text = district;
        regionController.text = region;
      });

      _msg(district.isEmpty
          ? 'GPS found, enter the district manually.'
          : 'Location and address detected.');
    } catch (e) {
      debugPrint('Profile location error: $e');
      _msg('Unable to fetch address. Enter it manually.');
    } finally {
      if (mounted) {
        setState(() {
          _fetchingLoc = false;
        });
      }
    }
  }

  // ============================================================
  // DESIGN HELPERS
  // ============================================================

  TextStyle _outfit(double size, FontWeight w, Color c,
      {double spacing = -0.2}) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: spacing,
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool required = true,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        cursorColor: _C.blue,
        style: GoogleFonts.manrope(
          color: readOnly && suffixIcon == null ? _C.muted : _C.ink,
          fontSize: 15,
        ),
        validator: validator ??
            (required
                ? (v) => v == null || v.trim().isEmpty ? 'Enter $label' : null
                : null),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: _C.muted, fontSize: 13.5),
          floatingLabelStyle: GoogleFonts.manrope(
            color: _C.blueDark,
            fontWeight: FontWeight.w700,
          ),
          errorStyle: GoogleFonts.manrope(
            color: const Color(0xFFD84B4B),
            fontSize: 11.5,
          ),
          prefixIcon: Icon(icon, color: _C.blueDark, size: 21),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _C.bg,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.line, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.line, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.blue, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.flag, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.flag, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: _C.shadow.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE7EEFF), Color(0xFFDCF6EC)],
                  ),
                ),
                child: Icon(icon, color: _C.blueDark, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _outfit(18, FontWeight.w600, _C.ink)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(color: _C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  BorderRadius _morph(double t, double s) {
    double l(double a, double b) => (a + (b - a) * t) * s;
    return BorderRadius.only(
      topLeft: Radius.elliptical(l(0.60, 0.40), l(0.50, 0.60)),
      topRight: Radius.elliptical(l(0.40, 0.60), l(0.60, 0.40)),
      bottomRight: Radius.elliptical(l(0.55, 0.45), l(0.40, 0.60)),
      bottomLeft: Radius.elliptical(l(0.45, 0.55), l(0.50, 0.40)),
    );
  }

  Widget _blob({
    required double size,
    required List<Color> colors,
    required double opacity,
    required bool reverse,
  }) {
    return AnimatedBuilder(
      animation: _blobCtrl,
      builder: (context, _) {
        final v = _blobCtrl.value;
        final m = (math.sin(v * 2 * math.pi * 3) + 1) / 2;
        final angle = (reverse ? -1 : 1) * v * 2 * math.pi;

        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: _morph(m, size),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _confetti(double left, double top, double d, Color color,
      double phase, double opacity) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (context, _) {
            final t =
            Curves.easeInOut.transform((_floatCtrl.value + phase) % 1.0);
            return Transform.translate(
              offset: Offset(16 * t, -24 * t),
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(opacity),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER CARD
  // ============================================================

  Widget _header() {
    ImageProvider? provider;
    if (_newImage != null) {
      provider = FileImage(_newImage!);
    } else if (_imageUrl.isNotEmpty) {
      provider = NetworkImage(_imageUrl);
    }

    final name = nameController.text.trim();
    final username = usernameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5F85FF), Color(0xFF8F7BFF), Color(0xFF5FD3B0)],
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -44,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: _C.bg,
                            backgroundImage: provider,
                            onBackgroundImageError:
                            provider is NetworkImage ? (_, __) {} : null,
                            child: provider == null
                                ? const Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: Color(0xFFB9C3E0),
                            )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _C.blueDark,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name.isEmpty ? 'Your name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _outfit(24, FontWeight.w700, Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  username.isEmpty ? '' : '@$username',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_status.isNotEmpty)
                      _headerChip(Icons.verified_rounded, _status),
                    if (regionController.text.trim().isNotEmpty)
                      _headerChip(
                          Icons.public_rounded, regionController.text.trim()),
                  ],
                ),
                if (_newImage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'New photo selected. Save to apply',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 11.5,
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

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _saveButton() {
    return Opacity(
      opacity: _saving ? 0.7 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_C.blueDark, _C.violet],
          ),
          boxShadow: [
            BoxShadow(
              color: _C.blue.withOpacity(0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 20),
                    const SizedBox(width: 9),
                    Text(
                      'Save changes',
                      style: GoogleFonts.manrope(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedBuilder(
                    animation: _shineCtrl,
                    builder: (context, _) {
                      final p =
                      ((_shineCtrl.value - 0.55) / 0.45).clamp(0.0, 1.0);
                      final left = -0.6 + 1.9 * p;
                      return Align(
                        alignment: Alignment((left / 0.64) * 2 - 1, 0),
                        child: FractionallySizedBox(
                          widthFactor: 0.36,
                          heightFactor: 1,
                          child: Transform(
                            transform: Matrix4.skewX(-0.36),
                            child: Container(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATES
  // ============================================================

  Widget _loadingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: _C.shadow.withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: _C.blue),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your profile...',
              style: GoogleFonts.manrope(
                color: _C.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _C.line),
            boxShadow: [
              BoxShadow(
                color: _C.shadow.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.flag.withOpacity(0.14),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: _C.flag, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load profile',
                style: _outfit(19, FontWeight.w600, _C.ink),
              ),
              const SizedBox(height: 6),
              Text(
                _loadError,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(color: _C.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  'Try again',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              _header(),
              const SizedBox(height: 20),

              // ---------------- PERSONAL ----------------
              _section(
                icon: Icons.badge_rounded,
                title: 'Personal details',
                subtitle: 'Keep your information up to date',
                children: [
                  _field(
                    label: 'Username',
                    controller: usernameController,
                    icon: Icons.alternate_email_rounded,
                    readOnly: true,
                    required: false,
                  ),
                  _field(
                    label: 'Full Name',
                    controller: nameController,
                    icon: Icons.person_outline_rounded,
                  ),
                  _field(
                    label: 'Phone',
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    label: 'Email',
                    controller: emailController,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter email';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  _field(
                    label: 'Date of Birth',
                    controller: dobController,
                    icon: Icons.cake_outlined,
                    readOnly: true,
                    suffixIcon: IconButton(
                      onPressed: _pickDob,
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        color: _C.blueDark,
                      ),
                    ),
                  ),
                ],
              ),

              // ---------------- LOCATION ----------------
              _section(
                icon: Icons.location_on_rounded,
                title: 'Location',
                subtitle: 'Tap the button to detect from GPS',
                trailing: Material(
                  color: _C.blue.withOpacity(0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _fetchingLoc ? null : _fetchLocation,
                    icon: const Icon(
                      Icons.my_location_rounded,
                      color: _C.blueDark,
                    ),
                    tooltip: 'Fetch current location',
                  ),
                ),
                children: [
                  if (_fetchingLoc)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          color: _C.mint,
                          backgroundColor: _C.line,
                        ),
                      ),
                    ),
                  _field(
                    label: 'Place / Locality',
                    controller: placeController,
                    icon: Icons.place_outlined,
                  ),
                  _field(
                    label: 'District',
                    controller: districtController,
                    icon: Icons.map_outlined,
                  ),
                  _field(
                    label: 'Region / State',
                    controller: regionController,
                    icon: Icons.public_rounded,
                  ),
                  _field(
                    label: 'Latitude',
                    controller: latitudeController,
                    icon: Icons.explore_outlined,
                    required: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null
                          ? 'Invalid latitude'
                          : null;
                    },
                  ),
                  _field(
                    label: 'Longitude',
                    controller: longitudeController,
                    icon: Icons.explore_outlined,
                    required: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null
                          ? 'Invalid longitude'
                          : null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 4),
              _saveButton(),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: Color(0xFF1F7A5C),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Your details are sent securely',
                    style: GoogleFonts.manrope(
                      color: _C.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_bgCtrl.value);
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + t * 0.8, -1),
                      end: Alignment(1, 1 - t * 0.8),
                      colors: const [
                        Color(0xFFE7EEFF),
                        Color(0xFFEFE7FF),
                        Color(0xFFDCF6EC),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: size.width / 2 - 170,
            top: size.height * 0.10 - 170,
            child: IgnorePointer(
              child: _blob(
                size: 340,
                colors: const [
                  Color(0xFFC9D8FF),
                  Color(0xFFE0D4FF),
                  Color(0xFFC7F3E3),
                ],
                opacity: 0.9,
                reverse: false,
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.45,
            top: size.height * 0.68,
            child: IgnorePointer(
              child: _blob(
                size: 240,
                colors: const [Color(0xFFFFE0D4), Color(0xFFFFF0C8)],
                opacity: 0.7,
                reverse: true,
              ),
            ),
          ),
          _confetti(size.width * 0.10, size.height * 0.14, 14, _C.peach, 0.0, 1.0),
          _confetti(size.width * 0.84, size.height * 0.10, 10, _C.sun, 0.33, 1.0),
          _confetti(size.width * 0.92, size.height * 0.52, 18, _C.lilac, 0.66, 0.7),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withOpacity(0.92),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: _C.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.maybePop(context),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: _C.ink,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Manage Profile',
                          textAlign: TextAlign.center,
                          style: _outfit(20, FontWeight.w600, _C.ink),
                        ),
                      ),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _loading
                          ? _loadingView()
                          : (_loadError.isNotEmpty ? _errorView() : _form()),
                    ),
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