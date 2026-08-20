import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../app_router.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  String _email = '';
  String? _currentImagePath;
  Uint8List? _newImage;
  DateTime? _birthdate;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await UserService.getProfile();
      if (!mounted) return;
      setState(() {
        _fullnameController.text = profile.fullname;
        _usernameController.text = profile.username;
        _email = profile.email;
        _currentImagePath = profile.profileImage;
        final raw = profile.birthdate;
        _birthdate = raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBDC9C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _ImageSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Pilih dari Galeri',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _ImageSourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Ambil Foto',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _newImage = bytes);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final fullname = _fullnameController.text.trim();
    final username = _usernameController.text.trim();
    if (fullname.isEmpty) {
      showAuthToast(context, 'Nama lengkap wajib diisi', isError: true);
      return;
    }
    if (username.length < 3) {
      showAuthToast(context, 'Username minimal 3 karakter', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_newImage != null) {
        await UserService.uploadProfileImage(_newImage!, 'profile.jpg');
      }
      final updated = await UserService.updateProfile(
        fullname: fullname,
        username: username,
        birthdate: _birthdate == null ? null : _formatDate(_birthdate!),
      );
      await AuthService.updateSession(fullname: fullname, username: username);

      if (!mounted) return;
      final delegate = AppRouter.of(context);
      delegate.updateUsername(updated.fullname);

      showAuthToast(context, 'Profil berhasil diperbarui');
      AppRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Edit Profil",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildAvatar(),
                            const SizedBox(height: 16),
                            Text(
                              _email.isEmpty ? 'Member FormUp' : _email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _fieldLabel("Nama Lengkap"),
                            AuthTextField(
                              controller: _fullnameController,
                              hint: "Nama lengkap",
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel("Username"),
                            AuthTextField(
                              controller: _usernameController,
                              hint: "Username",
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel("Tanggal Lahir"),
                            _birthdateTile(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthPrimaryButton(
                        label: _saving ? "Menyimpan..." : "Simpan Profil",
                        pill: true,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(50),
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFB8E2DE),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarContent(),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2A9D8F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarContent() {
    if (_newImage != null) {
      return Image.memory(
        _newImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    final path = _currentImagePath;
    if (path != null && path.isNotEmpty) {
      return Image.network(
        profileImageUrl(path),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    final name = _fullnameController.text.trim();
    return Center(
      child: Text(
        name.isEmpty ? 'U' : name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: kAuthPrimary,
        ),
      ),
    );
  }

  Widget _birthdateTile() {
    return InkWell(
      onTap: _pickBirthdate,
      borderRadius: BorderRadius.circular(7.5),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(7.5),
          border: Border.all(color: kAuthText),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: kAuthText),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _birthdate == null
                    ? 'Belum diatur'
                    : _displayDate(_birthdate!),
                style: TextStyle(
                  fontSize: 15,
                  color: _birthdate == null ? kAuthHint : Colors.black87,
                ),
              ),
            ),
            if (_birthdate != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: kAuthText),
                onPressed: () => setState(() => _birthdate = null),
              ),
          ],
        ),
      ),
    );
  }

  String _displayDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: kAuthPrimary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}
