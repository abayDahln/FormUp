import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';

/// Pengaturan aplikasi
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showComingSoon(BuildContext context, String feature) {
    showAuthToast(context, '$feature akan segera hadir.');
  }

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
            child: const Text('Keluar', style: TextStyle(color: kDangerColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthService.logout();
    if (!context.mounted) return;
    AppRouter.of(context).resetToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
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
          'Pengaturan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: AuthBackground(plain: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                _sectionLabel('Dukungan'),
                const SizedBox(height: 10),
                _settingsCard(children: [
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Bantuan & Dukungan',
                    onTap: () => _showComingSoon(context, 'Bantuan'),
                  ),
                  const _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'Tentang FormUp',
                    onTap: () => _showComingSoon(context, 'Tentang'),
                  ),
                  const _SettingsDivider(),
                  const _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'Versi Aplikasi',
                    trailing: Flexible(
                      child: Text(
                        '1.0.0',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 32),
                AuthPrimaryButton(
                  label: "Keluar dari Akun",
                  pill: true,
                  onPressed: () => _confirmLogout(context),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: kAuthHint,
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: elevationShadow(ShadowLevel.low),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
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
              child: Icon(icon, color: kAuthPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 54, color: Colors.black12);
  }
}

