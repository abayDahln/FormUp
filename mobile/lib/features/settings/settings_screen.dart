import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/theme_controller.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/onboarding_tour.dart';

/// Pengaturan aplikasi
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  /// Menu Panduan Aplikasi: LANGSUNG aksi — kembali + mulai tur Beranda
  /// dari awal (seperti user baru). Bukan sekadar teks panduan.
  void _openGuide() async {
    await OnboardingFlags.reset('home', AuthService.email);
    await OnboardingFlags.reset('questions', AuthService.email);
    if (!context.mounted) return;
    AppRouter.of(context).pop();
    // HomeScreen yang mendengar akan pindah ke tab Beranda + tampilkan tur.
    homeTourRequest.value++;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title:  Text(
          'Pengaturan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
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

                _sectionLabel('Tampilan'),
                const SizedBox(height: 10),
                _settingsCard(children: [
                  ValueListenableBuilder<AppThemeChoice>(
                    valueListenable: ThemeController.instance,
                    builder: (context, choice, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(choice.icon,
                                color: cs.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mode Tampilan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<AppThemeChoice>(
                              value: choice,
                              icon: Icon(Icons.arrow_drop_down,
                                  color: cs.onSurfaceVariant),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600),
                              dropdownColor: cs.surface,
                              items: [
                                for (final c in AppThemeChoice.values)
                                  DropdownMenuItem(
                                    value: c,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(c.icon,
                                            size: 18, color: cs.primary),
                                        const SizedBox(width: 8),
                                        Text(c.label),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  ThemeController.instance.setChoice(v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),

                _sectionLabel('Bantuan'),
                const SizedBox(height: 10),
                _settingsCard(children: [
                  _guideTile(
                    context,
                    icon: Icons.book_outlined,
                    title: 'Panduan Aplikasi',
                    subtitle: 'Baca panduan & ulangi tur interaktif',
                    onTap: _openGuide,
                  ),
                ]),
                const SizedBox(height: 24),

                const SizedBox(height: 8),
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
      style:  TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: elevationShadow(ShadowLevel.low),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }

  Widget _guideTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

