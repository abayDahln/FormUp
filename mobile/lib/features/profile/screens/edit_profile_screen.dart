import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/user_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/profile/widgets/birthdate_field.dart';
import 'package:form_up/features/profile/widgets/field_label.dart';
import 'package:form_up/features/profile/widgets/image_source_sheet.dart';
import 'package:form_up/features/profile/widgets/profile_avatar.dart';

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
    final source = await showImageSourceSheet(context);
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
          : AbsorbPointer(
              absorbing: _saving,
              child: AuthBackground(
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
                            ProfileAvatar(
                              currentImagePath: _currentImagePath,
                              newImage: _newImage,
                              name: _fullnameController.text,
                              onPick: _pickImage,
                            ),
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
                            const FieldLabel(text: "Nama Lengkap"),
                            AuthTextField(
                              controller: _fullnameController,
                              hint: "Nama lengkap",
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel(text: "Username"),
                            AuthTextField(
                              controller: _usernameController,
                              hint: "Username",
                              icon: Icons.alternate_email,
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel(text: "Tanggal Lahir"),
                            BirthdateField(
                              birthdate: _birthdate,
                              onPick: _pickBirthdate,
                              onClear: () => setState(() => _birthdate = null),
                            ),
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
          ),
    );
  }
}
