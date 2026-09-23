import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/empty_state.dart';
import 'package:form_up/core/utils/safe_load.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/services/user_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/widgets/redeem_api_key_sheet.dart';
import 'package:form_up/features/profile/widgets/image_source_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  /// Anchor tur panduan: baris Edit Profil & Ubah Kata Sandi.
  static final editTourKey = GlobalKey();
  static final passwordTourKey = GlobalKey();

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  UserStats? _stats;
  List<MyResponseItem> _recent = [];
  bool _loading = true;
  String? _loadError;
  // Guard agar swipe/spam/tick-online bersamaan tidak menumpuk request
  // (ApiCache juga dedup yang benar-benar bersamaan via _pending).
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    NetworkStatus.onlineTick.addListener(_onOnline);
    _load();
  }

  void _onOnline() {
    // Tanpa refresh paksa: cache fresh (≤2 mnt) = nol request, basi = fetch.
    if (mounted && NetworkStatus.isOnline) _load();
  }

  /// [refresh]=true melewati cache (swipe-refresh & setelah edit profil).
  /// Refresh senyap bila data sudah tampil: tidak ada full-loader,
  /// indikator hanya spinner bawaan AppRefreshIndicator.
  Future<void> _load({bool refresh = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final showLoader = _profile == null;
    if (showLoader) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      // Paralel tapi per-sumber: statistik gagal tidak boleh
      // menghanguskan profil (dan sebaliknya).
      final profileFut = captureLoad<UserProfile>(
        () => UserService.getProfile(refresh: refresh),
      );
      final statsFut = captureLoad<UserStats>(
        () => UserService.getStats(refresh: refresh),
      );
      // 1c: rekap aktivitas untuk panel kanan desktop (best-effort).
      final recentFut = captureLoad<List<MyResponseItem>>(
        () => FormService.getMyResponses(refresh: refresh),
      );
      final (profileVal, profileErr) = await profileFut;
      final (statsVal, statsErr) = await statsFut;
      final (recentVal, _) = await recentFut;
      if (!mounted) return;
      setState(() {
        if (profileVal != null) {
          _profile = profileVal;
          _loadError = null;
        } else if (profileErr != null &&
            showLoader &&
            AuthService.isConnectionError(profileErr)) {
          // Profil (data utama) gagal koneksi saat belum tampil:
          // tampilkan view retry penuh.
          _loadError = AuthService.errorMessage(profileErr);
        }
        if (statsVal != null) {
          _stats = statsVal;
        }
        if (recentVal != null) {
          _recent = recentVal.take(5).toList();
        }
      });
      // Error non-koneksi atau error saat data lama tampil: toast saja,
      // jangan timpa layar (data cache tetap berguna).
      final toastMsgs = <String>[];
      if (profileVal == null &&
          profileErr != null &&
          !(showLoader && AuthService.isConnectionError(profileErr))) {
        toastMsgs.add(AuthService.errorMessage(profileErr));
      }
      if (statsVal == null && statsErr != null) {
        toastMsgs.add(AuthService.errorMessage(statsErr));
      }
      for (final msg in toastMsgs) {
        if (!mounted) break;
        showAuthToast(context, msg, isError: true);
      }
    } finally {
      _refreshing = false;
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    await AppRouter.of(context).push(AppPage.editProfile);
    if (mounted) _load(refresh: true);
  }

  /// Sheet redeem API key Gemini (kode dari guru/admin → salin/terapkan).
  Future<void> _openRedeemApiKey() async {
    await RedeemApiKeySheet.show(context);
  }

  @override
  void dispose() {
    NetworkStatus.onlineTick.removeListener(_onOnline);
    super.dispose();
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
      // D6: tolak file raksasa di client (cegah OOM/timeout upload 20MB+).
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Foto profil maksimal 10 MB", isError: true);
        return;
      }
      // Loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppLoadingOverlay(),
      );
      try {
        await UserService.uploadProfileImage(bytes, 'profile.jpg');
        if (!mounted) return;
        Navigator.of(context).pop();
        showAuthToast(context, 'Foto profil diperbarui');
        await _load(refresh: true);
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

  /// 1c: tata dua panel desktop — kiri info akun + menu, kanan statistik +
  /// aktivitas terakhir. Phone memakai kartu tunggal seperti semula.
  Widget _buildWideContent(UserStats stats) {
    final cs = Theme.of(context).colorScheme;
    final email = _profile?.email ?? AuthService.email ?? '';
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(kRadius),
            boxShadow: elevationShadow(ShadowLevel.low),
          ),
          child: child,
        );
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Column(
            children: [
              _buildAvatar(size: 112),
              const SizedBox(height: 16),
              Text(
                _displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email.isEmpty ? 'Member FormUp' : email,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              if (_profile?.username.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  '@${_profile!.username}',
                  style: TextStyle(fontSize: 13, color: cs.primary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          Column(
            children: [
              _MenuTile(
                key: ProfileScreen.editTourKey,
                icon: Icons.person_outline,
                label: 'Edit Profil',
                onTap: _openEditProfile,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, indent: 52, color: Colors.black12),
              const SizedBox(height: 8),
              _MenuTile(
                key: ProfileScreen.passwordTourKey,
                icon: Icons.lock_outline,
                label: 'Ubah Kata Sandi',
                onTap: () =>
                    AppRouter.of(context).push(AppPage.changePassword),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, indent: 52, color: Colors.black12),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.key_outlined,
                label: 'Dapatkan API Key',
                onTap: _openRedeemApiKey,
              ),
            ],
          ),
        ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rekap',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                        label: 'Form Saya', value: '${stats.totalForms}'),
                  ),
                  Container(width: 1, height: 40, color: Colors.black12),
                  Expanded(
                    child: _MiniStat(
                        label: 'Dikerjakan',
                        value: '${stats.totalResponses}'),
                  ),
                  Container(width: 1, height: 40, color: Colors.black12),
                  Expanded(
                    child: _MiniStat(
                        label: 'Umpan Balik',
                        value: '${stats.totalFeedbackGiven}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aktivitas Terakhir',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (_recent.isEmpty)
                const EmptyState(
                  icon: Icons.history,
                  title: 'Belum ada aktivitas',
                  message: 'Respons yang Anda kerjakan akan muncul di sini.',
                  bare: true,
                )
              else
                for (var i = 0; i < _recent.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  InkWell(
                    onTap: () => AppRouter.of(context).push(
                      AppPage.formHistoryDetail,
                      {
                        'formLink': _recent[i].formLink,
                        'responseId': _recent[i].responseId,
                      },
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _recent[i].formTitle.isEmpty
                                      ? '(Tanpa judul)'
                                      : _recent[i].formTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13, color: cs.onSurface),
                                ),
                                Text(
                                  _formatRecentDate(_recent[i].submittedAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Window desktop sempit (< 700 lebar konten): tumpuk vertikal agar
        // kartu Rekap/menu tidak terjepit; lebar penuh identik phone.
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: right),
          ],
        );
      },
    );
  }

  static String _formatRecentDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final email = _profile?.email ?? AuthService.email ?? '';
    final stats = _stats ?? const UserStats();

    return SafeArea(
      child: AppRefreshIndicator(
        onRefresh: () => _load(refresh: true),
        indicatorColor: cs.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: centerPad(context, base: const EdgeInsets.fromLTRB(20, 15, 20, 24), maxWidth: 960, wideMaxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.onSurface,
                  ),
                ),
                InkWell(
                  onTap: () => AppRouter.of(context).push(AppPage.settings),
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child:  Icon(Icons.settings_outlined, color: cs.primary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: AppLoadingOverlay(),
              )
            else if (_loadError != null && _profile == null)
              ConnectionErrorView(
                message: _loadError!,
                onRetry: () => _load(refresh: true),
              )
            // 1c: desktop — dua panel (info akun | statistik + aktivitas).
            else if (isDesktopWidth(context))
              _buildWideContent(stats)
            else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(kRadius),
                  boxShadow: elevationShadow(ShadowLevel.low),
                ),
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      _displayName,
                      style:  TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'Member FormUp' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    if (_profile?.username.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${_profile!.username}',
                        style:  TextStyle(fontSize: 13, color: cs.primary),
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
                      key: ProfileScreen.editTourKey,
                      icon: Icons.person_outline,
                      label: 'Edit Profil',
                      onTap: _openEditProfile,
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, indent: 52, color: Colors.black12),
                    const SizedBox(height: 8),
                    _MenuTile(
                      key: ProfileScreen.passwordTourKey,
                      icon: Icons.lock_outline,
                      label: 'Ubah Kata Sandi',
                      onTap: () =>
                          AppRouter.of(context).push(AppPage.changePassword),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, indent: 52, color: Colors.black12),
                    const SizedBox(height: 8),
                    _MenuTile(
                      icon: Icons.key_outlined,
                      label: 'Dapatkan API Key',
                      onTap: _openRedeemApiKey,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAvatar({double size = 90}) {
    return GestureDetector(
      onTap: _pickAvatarImage,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFFB8E2DE),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarContent(size * 0.4),
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

  Widget _avatarContent([double fontSize = 36]) {
    final path = _profile?.profileImage;
    if (path == null || path.isEmpty) {
      return Center(
        child: Text(
          _initial,
          style:  TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return Image(
      image: adaptiveNetworkImage(profileImageUrl(path)),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          _initial,
          style:  TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(context).colorScheme.primary,
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style:  TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:  TextStyle(fontSize: 15, color: cs.onSurface),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

