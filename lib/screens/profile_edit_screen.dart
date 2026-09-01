import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_color.dart';
import '../services/api_config_service.dart';
import '../services/get_profile_service.dart';
import '../services/profile_submit_api_service.dart';
import '../services/session_manager.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtr   = TextEditingController();
  final _mobileCtr = TextEditingController();
  final _emailCtr  = TextEditingController();

  bool    _loading         = false;
  bool    _saving          = false;
  String? _pickedImagePath;
  String? _serverImageUrl;   // profile_image from API

  String? _telephone;
  String _kName(String phone)  => 'profile_name_$phone';
  String _kEmail(String phone) => 'profile_email_$phone';
  String _kImage(String phone) => 'profile_image_$phone';

  @override
  void initState() {
    super.initState();
    _loadFromApi();
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _mobileCtr.dispose();
    _emailCtr.dispose();
    super.dispose();
  }

  // ── Load profile from API ──────────────────────────────────────────────────
  Future<void> _loadFromApi() async {
    setState(() => _loading = true);

    try {
      final result = await ProfileGetApiService.getProfile();

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;

        final firstName  = data['firstname']     as String? ?? '';
        final lastName   = data['lastname']      as String? ?? '';
        final email      = data['email']         as String? ?? '';
        final telephone  = data['telephone']     as String? ?? '';
        final profileImg = data['profile_image'] as String? ?? '';

        final fullName = [firstName, lastName]
            .where((s) => s.isNotEmpty)
            .join(' ');

        _telephone = telephone;

        if (mounted) {
          setState(() {
            _nameCtr.text    = fullName;
            _mobileCtr.text  = telephone;
            _emailCtr.text   = email;
            _serverImageUrl  = profileImg.isNotEmpty ? profileImg : null;
            _loading         = false;
          });
        }
      } else {
        await _loadFromLocal();
      }
    } catch (e) {
      await _loadFromLocal();
    }
  }

  // ── Fallback: load from local SharedPreferences ────────────────────────────
  Future<void> _loadFromLocal() async {
    final telephone = await SessionManager.getTelephone();
    _telephone = telephone ?? '';

    final savedName  = await SessionManager.getString(_kName(_telephone!));
    final savedEmail = await SessionManager.getString(_kEmail(_telephone!));
    final savedImage = await SessionManager.getString(_kImage(_telephone!));

    if (mounted) {
      setState(() {
        _mobileCtr.text  = _telephone!;
        _nameCtr.text    = savedName  ?? '';
        _emailCtr.text   = savedEmail ?? '';
        _pickedImagePath = (savedImage != null && savedImage.isNotEmpty)
            ? savedImage
            : null;
        _loading = false;
      });
    }
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    await _showImageSourceSheet();
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceOption(
                  icon: Icons.camera_front,
                  label: 'Selfie',
                  color: AppColors.primaryBlue,
                  onTap: () async {
                    Navigator.pop(context);
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      preferredCameraDevice: CameraDevice.front,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      setState(() {
                        _pickedImagePath = picked.path;
                        _serverImageUrl  = null;
                      });
                    }
                  },
                ),
                _imageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Album',
                  color: AppColors.freshGreen,
                  onTap: () async {
                    Navigator.pop(context);
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      setState(() {
                        _pickedImagePath = picked.path;
                        _serverImageUrl  = null;
                      });
                    }
                  },
                ),
                if (_pickedImagePath != null || _serverImageUrl != null)
                  _imageSourceOption(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _pickedImagePath = null;
                        _serverImageUrl  = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_telephone == null) return;

    setState(() => _saving = true);

    try {
      final fullName  = _nameCtr.text.trim();
      final nameParts = fullName.split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
      final lastName  = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      final token     = await SessionManager.getToken() ?? '';
      final imageFile = _pickedImagePath != null
          ? File(_pickedImagePath!)
          : null;

      final result = await ProfileApiService.updateProfile(
        token:     token,
        telephone: _telephone!,
        firstName: firstName,
        lastName:  lastName,
        email:     _emailCtr.text.trim(),
        imageFile: imageFile,
      );

      if (!mounted) return;

      if (result['status'] == 'success') {
        // Cache updated values locally
        await SessionManager.setString(_kName(_telephone!),  fullName);
        await SessionManager.setString(_kEmail(_telephone!), _emailCtr.text.trim());

        final serverImage = result['image'] as String?;
        await SessionManager.setString(
            _kImage(_telephone!), serverImage ?? _pickedImagePath ?? '');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
            behavior:        SnackBarBehavior.floating,
            duration:        Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      } else {
        _showError(result['message'] ?? 'Something went wrong');
      }

    } on TokenInvalidException catch (e) {
      if (!mounted) return;
      _showError(e.message);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await SessionManager.clearSession();
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', (route) => false,
      );
    } on SocketException {
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      _showError('Failed to update profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(message),
        backgroundColor: AppColors.error,
        behavior:        SnackBarBehavior.floating,
        duration:        const Duration(seconds: 3),
      ),
    );
  }

  // ── Avatar widget (handles server URL + local file + placeholder) ──────────
  Widget _buildAvatar() {
    ImageProvider? imageProvider;

    if (_pickedImagePath != null && File(_pickedImagePath!).existsSync()) {
      imageProvider = FileImage(File(_pickedImagePath!));
    } else if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty) {
      final fullUrl = _serverImageUrl!.startsWith('http')
          ? _serverImageUrl!
          : ApiConfig.imageBase + _serverImageUrl!;
      imageProvider = NetworkImage(fullUrl);
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(Icons.person, color: AppColors.primaryBlue, size: 48)
              : null,
        ),
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
                color: AppColors.primaryOrange, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, color: AppColors.white, size: 14),
          ),
        ),
      ]),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Avatar ───────────────────────────────────────────
              Center(child: _buildAvatar()),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change photo',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.appBarText),
                ),
              ),
              const SizedBox(height: 28),

              // ── Name ─────────────────────────────────────────────
              _fieldLabel('Name *'),
              const SizedBox(height: 8),
              _buildField(
                controller:   _nameCtr,
                hint:         'Enter your name',
                keyboardType: TextInputType.name,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 24),

              // ── Mobile ───────────────────────────────────────────
              _fieldLabel('Mobile Number *'),
              const SizedBox(height: 8),
              _buildField(
                controller:      _mobileCtr,
                hint:            'Mobile number',
                keyboardType:    TextInputType.phone,
                readOnly:        true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Mobile is required'
                    : null,
              ),
              const SizedBox(height: 24),

              // ── Email ────────────────────────────────────────────
              _fieldLabel('Email Address *'),
              const SizedBox(height: 8),
              _buildField(
                controller:   _emailCtr,
                hint:         'Enter your email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex =
                  RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'We promise not to spam you',
                style: TextStyle(
                    fontSize: 12, color: AppColors.appBarText),
              ),
              const SizedBox(height: 36),

              // ── Submit ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.textLight,
                          strokeWidth: 2.5))
                      : const Text(
                    'Submit',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Field label: black text ────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary),   // black
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      readOnly:        readOnly,
      inputFormatters: inputFormatters,
      validator:       validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        filled:    true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: Colors.black, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: AppColors.appBarText, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: AppColors.error, width: 1.5),
        ),
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline,
            size: 16, color: AppColors.textMuted)
            : null,
      ),
    );
  }
}