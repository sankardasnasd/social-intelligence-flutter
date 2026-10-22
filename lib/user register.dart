import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_intelligent/login.dart';

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

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({super.key});

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final regionController = TextEditingController();
  final placeController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final districtController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  final Location location = Location();
  final ImagePicker picker = ImagePicker();

  File? profileImage;
  bool isFetchingLocation = false;
  bool isSubmitting = false;
  bool obscurePassword = true;

  // ---- design only: animation controllers ----
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

    final curve = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      getCurrentLocation();
    });
  }

  String firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Future<void> pickProfilePicture() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          profileImage = File(image.path);
        });
      }
    } catch (e) {
      showMessage('Unable to select profile picture.');
    }
  }

  Future<void> getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      isFetchingLocation = true;
    });

    try {
      bool serviceEnabled = await location.serviceEnabled();

      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }

      if (!serviceEnabled) {
        showMessage('Please enable GPS.');
        return;
      }

      PermissionStatus permission = await location.hasPermission();

      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }

      if (permission != PermissionStatus.granted) {
        showMessage('Please allow location permission.');
        return;
      }

      final LocationData gps = await location.getLocation();

      if (gps.latitude == null || gps.longitude == null) {
        showMessage('Unable to get GPS coordinates.');
        return;
      }

      final double lat = gps.latitude!;
      final double lon = gps.longitude!;

      if (!mounted) return;

      setState(() {
        latitudeController.text = lat.toString();
        longitudeController.text = lon.toString();
      });

      final List<geo.Placemark> addresses =
      await geo.placemarkFromCoordinates(lat, lon);

      if (addresses.isEmpty) {
        showMessage('Address not found. Enter details manually.');
        return;
      }

      // Print all results to help identify the correct district field.
      for (int i = 0; i < addresses.length; i++) {
        final a = addresses[i];

        debugPrint('--- Address result $i ---');
        debugPrint('Name: ${a.name}');
        debugPrint('Street: ${a.street}');
        debugPrint('SubLocality: ${a.subLocality}');
        debugPrint('Locality: ${a.locality}');
        debugPrint('SubAdministrativeArea: ${a.subAdministrativeArea}');
        debugPrint('AdministrativeArea: ${a.administrativeArea}');
        debugPrint('PostalCode: ${a.postalCode}');
      }

      // Prefer a more specific locality for Place.
      final first = addresses.first;

      final String detectedPlace = firstNonEmpty([
        first.subLocality,
        first.name,
        first.thoroughfare,
        first.locality,
        first.street,
      ]);

      // Check every returned result for a district/administrative area.
      String detectedDistrict = '';

      for (final a in addresses) {
        detectedDistrict = firstNonEmpty([
          a.subAdministrativeArea,
        ]);

        if (detectedDistrict.isNotEmpty) break;
      }

      // Best-effort fallback if district is not returned separately.
      if (detectedDistrict.isEmpty) {
        for (final a in addresses) {
          final candidate = firstNonEmpty([a.locality]);

          if (candidate.isNotEmpty &&
              candidate.toLowerCase() !=
                  detectedPlace.toLowerCase()) {
            detectedDistrict = candidate;
            break;
          }
        }
      }

      // Prefer the state field for Region.
      final String detectedRegion = firstNonEmpty(
        addresses.map((a) => a.administrativeArea).toList(),
      );

      if (!mounted) return;

      setState(() {
        placeController.text = detectedPlace;
        districtController.text = detectedDistrict;
        regionController.text = detectedRegion;
      });

      if (detectedDistrict.isEmpty) {
        showMessage(
          'GPS found, but district was not returned. '
              'Please enter the district manually.',
        );
      } else {
        showMessage('Location and address detected.');
      }
    } catch (e) {
      debugPrint('Location/geocoding error: $e');
      showMessage('Unable to fetch address. Enter it manually.');
    } finally {
      if (mounted) {
        setState(() {
          isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> selectDateOfBirth() async {
    final now = DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected != null && mounted) {
      dobController.text =
      '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();

      String baseUrl = sh.getString('url') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        showMessage('Server URL not configured.');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_register/');

      final request = http.MultipartRequest(
        'POST',
        url,
      );

      request.fields.addAll({
        'name': nameController.text.trim(),
        'region': regionController.text.trim(),
        'place': placeController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'dob': dobController.text.trim(),
        'district': districtController.text.trim(),
        'username': usernameController.text.trim(),
        'password': passwordController.text,
        'latitude': latitudeController.text.trim(),
        'longitude': longitudeController.text.trim(),
      });

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            profileImage!.path,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response =
      await http.Response.fromStream(streamedResponse);

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result =
        jsonDecode(response.body) as Map<String, dynamic>;

        if (result['status'] == 'ok') {
          showMessage('Registration successful.');
          Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));

          _formKey.currentState!.reset();

          for (final controller in [
            nameController,
            regionController,
            placeController,
            phoneController,
            emailController,
            dobController,
            districtController,
            usernameController,
            passwordController,
            latitudeController,
            longitudeController,
          ]) {
            controller.clear();
          }

          setState(() {
            profileImage = null;
          });
        } else {
          showMessage(
            result['message']?.toString() ??
                'Username or email already exists.',
          );
        }
      } else {
        showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      showMessage(
        'Unable to connect. Check the API URL and server.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(color: _C.ink),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _C.line),
        ),
      ),
    );
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

  Widget textField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
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
        style: GoogleFonts.manrope(color: _C.ink, fontSize: 15),
        validator: validator ??
                (value) => value == null || value.trim().isEmpty
                ? 'Enter $label'
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(
            color: _C.muted,
            fontSize: 13.5,
          ),
          floatingLabelStyle: GoogleFonts.manrope(
            color: _C.blueDark,
            fontWeight: FontWeight.w700,
          ),
          errorStyle: GoogleFonts.manrope(
            color: const Color(0xFFD84B4B),
            fontSize: 11.5,
          ),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: _C.blueDark, size: 21),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _C.bg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
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

  // white rounded section card with gradient icon header
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
                      style: GoogleFonts.manrope(
                        color: _C.muted,
                        fontSize: 12,
                      ),
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

  Widget _avatar() {
    return Column(
      children: [
        GestureDetector(
          onTap: pickProfilePicture,
          child: SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_C.blue, _C.lilac, _C.mint],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.shadow.withOpacity(0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: _C.bg,
                    backgroundImage: profileImage != null
                        ? FileImage(profileImage!)
                        : null,
                    child: profileImage == null
                        ? const Icon(
                      Icons.person_rounded,
                      size: 46,
                      color: Color(0xFFB9C3E0),
                    )
                        : null,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.blue,
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
        const SizedBox(height: 10),
        Text(
          'Tap to select profile picture',
          style: GoogleFonts.manrope(
            color: _C.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _blobCtrl.dispose();
    _floatCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    nameController.dispose();
    regionController.dispose();
    placeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dobController.dispose();
    districtController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ------------------------------------------------
          // SOFT MOVING GRADIENT
          // ------------------------------------------------
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

          // ------------------------------------------------
          // BLOBS + CONFETTI
          // ------------------------------------------------
          Positioned(
            left: size.width / 2 - 170,
            top: size.height * 0.12 - 170,
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
            top: size.height * 0.66,
            child: IgnorePointer(
              child: _blob(
                size: 240,
                colors: const [Color(0xFFFFE0D4), Color(0xFFFFF0C8)],
                opacity: 0.7,
                reverse: true,
              ),
            ),
          ),
          _confetti(size.width * 0.10, size.height * 0.14, 14, _C.peach, 0.0,
              1.0),
          _confetti(size.width * 0.84, size.height * 0.10, 10, _C.sun, 0.33,
              1.0),
          _confetti(size.width * 0.92, size.height * 0.50, 18, _C.lilac,
              0.66, 0.7),

          // ------------------------------------------------
          // CONTENT
          // ------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                // ---- top bar ----
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
                          'User Registration',
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
                      child: Form(
                        key: _formKey,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                              const EdgeInsets.fromLTRB(20, 18, 20, 30),
                              children: [
                                Center(child: _avatar()),
                                const SizedBox(height: 22),

                                // ---------------- PERSONAL ----------------
                                _section(
                                  icon: Icons.badge_rounded,
                                  title: 'Personal details',
                                  subtitle: 'Tell us who you are',
                                  children: [
                                    textField(
                                      label: 'Full Name',
                                      controller: nameController,
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    textField(
                                      label: 'Phone',
                                      controller: phoneController,
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    textField(
                                      label: 'Email',
                                      controller: emailController,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType:
                                      TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter email';
                                        }

                                        if (!RegExp(
                                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                            .hasMatch(value.trim())) {
                                          return 'Enter a valid email';
                                        }

                                        return null;
                                      },
                                    ),
                                    textField(
                                      label: 'Date of Birth',
                                      controller: dobController,
                                      icon: Icons.cake_outlined,
                                      readOnly: true,
                                      suffixIcon: IconButton(
                                        onPressed: selectDateOfBirth,
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
                                  title: 'Current location',
                                  subtitle: 'Detected from your GPS',
                                  trailing: Material(
                                    color: _C.blue.withOpacity(0.10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      onPressed: isFetchingLocation
                                          ? null
                                          : getCurrentLocation,
                                      icon: const Icon(
                                        Icons.my_location_rounded,
                                        color: _C.blueDark,
                                      ),
                                      tooltip: 'Fetch current location',
                                    ),
                                  ),
                                  children: [
                                    if (isFetchingLocation)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(bottom: 14),
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(4),
                                          child: const LinearProgressIndicator(
                                            minHeight: 4,
                                            color: _C.mint,
                                            backgroundColor: _C.line,
                                          ),
                                        ),
                                      ),
                                    textField(
                                      label: 'Place / Locality',
                                      controller: placeController,
                                      icon: Icons.place_outlined,
                                    ),
                                    textField(
                                      label: 'District',
                                      controller: districtController,
                                      icon: Icons.map_outlined,
                                    ),
                                    textField(
                                      label: 'Region / State',
                                      controller: regionController,
                                      icon: Icons.public_rounded,
                                    ),
                                    textField(
                                      label: 'Latitude',
                                      controller: latitudeController,
                                      icon: Icons.explore_outlined,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                    ),
                                    textField(
                                      label: 'Longitude',
                                      controller: longitudeController,
                                      icon: Icons.explore_outlined,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                    ),
                                  ],
                                ),

                                // ---------------- ACCOUNT ----------------
                                _section(
                                  icon: Icons.lock_rounded,
                                  title: 'Account',
                                  subtitle: 'Choose your sign in details',
                                  children: [
                                    textField(
                                      label: 'Username',
                                      controller: usernameController,
                                      icon: Icons.alternate_email_rounded,
                                    ),
                                    textField(
                                      label: 'Password',
                                      controller: passwordController,
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            obscurePassword =
                                            !obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: _C.muted,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Enter password';
                                        }
                                        if (value.length < 8) {
                                          return 'Password must contain at least 8 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                // ---------------- REGISTER BUTTON ----------------
                                Opacity(
                                  opacity: isSubmitting ? 0.7 : 1,
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
                                            onPressed: isSubmitting
                                                ? null
                                                : registerUser,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                              Colors.transparent,
                                              disabledBackgroundColor:
                                              Colors.transparent,
                                              foregroundColor: Colors.white,
                                              disabledForegroundColor:
                                              Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: isSubmitting
                                                ? const SizedBox(
                                              width: 23,
                                              height: 23,
                                              child:
                                              CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                                : Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .center,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 9),
                                                Text(
                                                  'REGISTER',
                                                  style:
                                                  GoogleFonts.manrope(
                                                    fontSize: 15,
                                                    fontWeight:
                                                    FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // moving shine
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                              child: AnimatedBuilder(
                                                animation: _shineCtrl,
                                                builder: (context, _) {
                                                  final p = ((_shineCtrl
                                                      .value -
                                                      0.55) /
                                                      0.45)
                                                      .clamp(0.0, 1.0);
                                                  final left = -0.6 + 1.9 * p;
                                                  return Align(
                                                    alignment: Alignment(
                                                        (left / 0.64) * 2 - 1,
                                                        0),
                                                    child:
                                                    FractionallySizedBox(
                                                      widthFactor: 0.36,
                                                      heightFactor: 1,
                                                      child: Transform(
                                                        transform:
                                                        Matrix4.skewX(
                                                            -0.36),
                                                        child: Container(
                                                          color: Colors.white
                                                              .withOpacity(
                                                              0.35),
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
                                ),

                                const SizedBox(height: 18),

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
                      ),
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