import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../app_router.dart';

class ProfileScreen extends StatelessWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar', style: TextStyle(fontFamily: kFontBold)),
        content: const Text('Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthService.logout();
    if (!context.mounted) return;
    AppRouter.of(context).resetToLogin();
  }

  void _showComingSoon(BuildContext context, String feature) {
    showAuthToast(context, '$feature akan segera hadir.');
  }

  String get _initial {
    final name = username.trim();
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }
  @override
  Widget build(BuildContext context) {
    final displayName = username.trim().isNotEmpty ? username : 'Pengguna';
    final email = AuthService.email ?? '';

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xCCBDC9C8)),
                  ),
                  child: const Icon(Icons.settings_outlined, color: kAuthPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadius),
                boxShadow: softShadow(),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB8E2DE),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
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
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A9D8F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
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
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _MiniStat(label: 'Form', value: '5')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Respons', value: '12')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Umpan Balik', value: '2')),
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
                    onTap: () => _showComingSoon(context, 'Edit profil'),
                  ),
                  const Divider(height: 1, indent: 52, color: Colors.black12),
                  _MenuTile(
                    icon: Icons.lock_outline,
                    label: 'Ubah Kata Sandi',
                    onTap: () =>
                        AppRouter.of(context).push(AppPage.changePassword),
                  ),
                  const Divider(height: 1, indent: 52, color: Colors.black12),
                  _MenuTile(
                    icon: Icons.help_outline,
                    label: 'Bantuan & Dukungan',
                    onTap: () => _showComingSoon(context, 'Bantuan'),
                  ),
                  const Divider(height: 1, indent: 52, color: Colors.black12),
                  _MenuTile(
                    icon: Icons.info_outline,
                    label: 'Tentang FormUp',
                    onTap: () => _showComingSoon(context, 'Tentang'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC0392B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Keluar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                  ),
                ),
              ),
            ),
          ],
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

