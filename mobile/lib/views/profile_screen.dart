import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../app_router.dart';

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
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadius),
                  boxShadow: softShadow(),
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Form Saya', value: '${stats.totalForms}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'Form Dikerjakan', value: '${stats.totalResponses}')),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.person_outline,
                      label: 'Edit Profil',
                      onTap: _openEditProfile,
                    ),
                    const Divider(height: 1, indent: 52, color: Colors.black12),
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
    return Stack(
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
        const Positioned(
          right: 0,
          bottom: 0,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2A9D8F),
            child: Icon(Icons.edit, color: Colors.white, size: 14),
          ),
        ),
      ],
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
    return Image.network(
      profileImageUrl(path),
      fit: BoxFit.cover,
      cacheWidth: 300,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
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
      ),
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
    return ListTile(
      leading: Icon(icon, color: kAuthPrimary, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
