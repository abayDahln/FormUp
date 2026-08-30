import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/user_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/profile/widgets/image_source_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  UserStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([UserService.getProfile(), UserService.getStats()]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _stats = results[1] as UserStats;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    await AppRouter.of(context).push(AppPage.editProfile);
    if (mounted) _load();
  }

  Future<void> _pickAvatarImage() async {
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
      final Uint8List bytes = await picked.readAsBytes();
      if (!mounted) return;
      // Loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: AppLoadingIndicator.circular()),
      );
      try {
        await UserService.uploadProfileImage(bytes, 'profile.jpg');
        if (!mounted) return;
        Navigator.of(context).pop();
        showAuthToast(context, 'Foto profil diperbarui');
        await _load();
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        showAuthToast(context, AuthService.errorMessage(e), isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  String get _initial {
    final name = _profile?.fullname.trim() ?? widget.username.trim();
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  String get _displayName {
    final name = _profile?.fullname.trim();
    if (name != null && name.isNotEmpty) return name;
    return widget.username.trim().isNotEmpty ? widget.username : 'Pengguna';
  }

  @override
  Widget build(BuildContext context) {
    final email = _profile?.email ?? AuthService.email ?? '';
    final stats = _stats ?? const UserStats();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                InkWell(
                  onTap: () => AppRouter.of(context).push(AppPage.settings),
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xCCBDC9C8)),
                    ),
                    child: const Icon(Icons.settings_outlined, color: kAuthPrimary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: AppLoadingIndicator.circular()),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadius),
                  boxShadow: elevationShadow(ShadowLevel.low),
                ),
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'Member FormUp' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    if (_profile?.username.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${_profile!.username}',
                        style: const TextStyle(fontSize: 13, color: kAuthPrimary),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(label: 'Form Saya', value: '${stats.totalForms}'),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.black12,
                        ),
                        Expanded(
                          child: _MiniStat(label: 'Form Dikerjakan', value: '${stats.totalResponses}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 8),
                    _MenuTile(
                      icon: Icons.person_outline,
                      label: 'Edit Profil',
                      onTap: _openEditProfile,
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, indent: 52, color: Colors.black12),
                    const SizedBox(height: 8),
                    _MenuTile(
                      icon: Icons.lock_outline,
                      label: 'Ubah Kata Sandi',
                      onTap: () =>
                          AppRouter.of(context).push(AppPage.changePassword),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickAvatarImage,
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
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
            child: GestureDetector(
              onTap: _pickAvatarImage,
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF2A9D8F),
                child: Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarContent() {
    final path = _profile?.profileImage;
    if (path == null || path.isEmpty) {
      return Center(
        child: Text(
          _initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
      );
    }
    return Image(
      image: CachedNetworkImageProvider(profileImageUrl(path)),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          _initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kAuthPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

