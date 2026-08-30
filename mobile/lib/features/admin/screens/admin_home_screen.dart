import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/user_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/admin/screens/admin_panel_screen.dart';

/// Shell aplikasi untuk admin: Beranda, Kelola, Profil — dengan navigation bar.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  // ponytail: IndexedStack lazy, state terjaga
  final Set<int> _visitedTabs = {0};

  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final profile = await UserService.getProfile();
      if (!mounted) return;
      setState(() => _name = profile.fullname);
    } catch (_) {
      // ponytail: nama sapaan gagal dimuat tidak fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _AdminBerandaTab(
              name: _name,
              onOpenManage: () => setState(() {
                _visitedTabs.add(1);
                _currentIndex = 1;
              }),
            ),
            if (_visitedTabs.contains(1))
              const AdminPanelContent()
            else
              const SizedBox.shrink(),
            if (_visitedTabs.contains(2))
              const _AdminProfileTab()
            else
              const SizedBox.shrink(),
          ],
          ),
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) return;
            setState(() {
              _visitedTabs.add(index);
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: kPrimary,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 22,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Kelola',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Beranda (admin)
// ---------------------------------------------------------------------------
class _AdminBerandaTab extends StatefulWidget {
  final String name;
  final VoidCallback onOpenManage;

  const _AdminBerandaTab({
    required this.name,
    required this.onOpenManage,
  });

  @override
  State<_AdminBerandaTab> createState() => _AdminBerandaTabState();
}

class _AdminBerandaTabState extends State<_AdminBerandaTab> {
  bool _loading = true;
  int _totalUsers = 0;
  int _totalForms = 0;
  int _totalFeedback = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Ringkasan diambil dari field `total` endpoint list (pageSize 1).
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AdminService.getUsers(page: 1, pageSize: 1),
        AdminService.getForms(page: 1, pageSize: 1),
        AdminService.getFeedbacks(page: 1, pageSize: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _totalUsers = results[0].total;
        _totalForms = results[1].total;
        _totalFeedback = results[2].total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Halo, ${widget.name.isNotEmpty ? widget.name : 'Admin'}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AuthService.role == 'ADMIN'
                  ? "Panel administrasi FormUp"
                  : "Panel administrasi",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_outline,
                    label: 'User',
                    value: _loading ? null : _totalUsers,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.description_outlined,
                    label: 'Form',
                    value: _loading ? null : _totalForms,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.forum_outlined,
                    label: 'Feedback',
                    value: _loading ? null : _totalFeedback,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "Aksi Cepat",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.people_outline,
              title: 'Kelola User',
              subtitle: 'Lihat, ban, dan hapus user terdaftar',
              onTap: widget.onOpenManage,
            ),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.description_outlined,
              title: 'Kelola Form',
              subtitle: 'Takedown, restore, dan hapus form',
              onTap: widget.onOpenManage,
            ),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.forum_outlined,
              title: 'Feedback Masuk',
              subtitle: 'Tinjau laporan dari pengguna',
              onTap: widget.onOpenManage,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// Kartu statistik ringkas
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: elevationShadow(ShadowLevel.low),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kPrimarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kAuthPrimary, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            value == null ? '—' : '$value',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// Tile aksi cepat di beranda admin
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

@override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: elevationShadow(ShadowLevel.subtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: kPrimarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: kAuthPrimary, size: 21),
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
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Profil (admin)
// ---------------------------------------------------------------------------
class _AdminProfileTab extends StatefulWidget {
  const _AdminProfileTab();

  @override
  State<_AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<_AdminProfileTab> {
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
      final results =
          await Future.wait([UserService.getProfile(), UserService.getStats()]);
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

  String get _initial {
    final name = _profile?.fullname.trim() ?? '';
    if (name.isEmpty) return 'A';
    return name[0].toUpperCase();
  }

  String get _displayName {
    final name = _profile?.fullname.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    final email = _profile?.email ?? AuthService.email ?? '';
    final stats = _stats ?? const UserStats();

    return SingleChildScrollView(
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
                  child: const Icon(Icons.settings_outlined,
                      color: kAuthPrimary, size: 20),
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
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: kPrimarySoft,
                    backgroundImage:
                        (_profile?.profileImage ?? '').isNotEmpty
                            ? CachedNetworkImageProvider(_profile!.profileImage!)
                            : null,
                    child: (_profile?.profileImage ?? '').isEmpty
                        ? Text(
                            _initial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: kAuthPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadius),
                boxShadow: elevationShadow(ShadowLevel.low),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('${stats.totalForms}', 'Form Dibuat'),
                  _verticalDivider(),
                  _stat('${stats.totalResponses}', 'Respons'),
                  _verticalDivider(),
                  _stat('${stats.totalFeedbackGiven}', 'Feedback'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: elevationShadow(ShadowLevel.low),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.edit_outlined, color: kAuthPrimary),
                      title: const Text('Edit Profil',
                          style: TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey),
                      onTap: () async {
                        await AppRouter.of(context).push(AppPage.editProfile);
                        if (mounted) _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.black12,
    );
  }
}
