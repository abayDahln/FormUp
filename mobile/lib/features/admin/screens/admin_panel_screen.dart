import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/features/home/widgets/response_tab_switcher.dart';

enum _AdminTab { users, forms, feedback }

/// Konten tab "Kelola" pada shell admin: kelola user, form, dan feedback.
/// Ditampilkan di dalam AdminHomeScreen (tanpa Scaffold sendiri).
class AdminPanelContent extends StatefulWidget {
  const AdminPanelContent({super.key});

  @override
  State<AdminPanelContent> createState() => _AdminPanelContentState();
}

class _AdminPanelContentState extends State<AdminPanelContent> {
  _AdminTab _tab = _AdminTab.users;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelola',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'User, form, dan feedback platform',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ResponseTabSwitcher(
              items: const [
                ResponseTabItem(icon: Icons.people_outline, label: 'User'),
                ResponseTabItem(
                    icon: Icons.description_outlined, label: 'Form'),
                ResponseTabItem(icon: Icons.forum_outlined, label: 'Feedback'),
              ],
              activeIndex: _tab.index,
              onChanged: (i) => setState(() => _tab = _AdminTab.values[i]),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: switch (_tab) {
              _AdminTab.users => const _AdminUsersTab(),
              _AdminTab.forms => const _AdminFormsTab(),
              _AdminTab.feedback => const _AdminFeedbackTab(),
            },
          ),
        ],
      ),
    );
  }
}

/// Search field bergaya konsisten dengan tab Riwayat/Analisis
class _AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const _AdminSearchField({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      onChanged: onChanged,
      hint: hint,
    );
  }
}

/// Item navigasi halaman di dalam list: prev / "Halaman X dari Y" / next,
/// dipisah dengan spaceBetween.
class PageNavFooter extends StatelessWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const PageNavFooter({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 22),
          color: kAuthPrimary,
        ),
        Text(
          'Halaman $page dari $totalPages',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 22),
          color: kAuthPrimary,
        ),
      ],
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}

// ---------------------------------------------------------------------------
// Tab User
// ---------------------------------------------------------------------------
class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();

  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<AdminUserItem> _users = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final result = await AdminService.getUsers(
        page: page,
        pageSize: _pageSize,
        search: _query,
      );
      if (!mounted) return;
      setState(() {
        _users = result.items;
        _page = page;
        _totalPages = result.total <= 0
            ? 1
            : (result.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPage(int page) {
    if (page == _page || page < 1 || page > _totalPages) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _load(page: page);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: _AdminSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hint: 'Cari nama, username, atau email...',
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: kAuthPrimary,
            onRefresh: () => _load(),
            child: !_loading && _users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.person_off_outlined,
                                color: Colors.grey, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              _query.isEmpty
                                  ? 'Belum ada user'
                                  : 'Tidak ada hasil untuk "${_searchController.text}"',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount:
                            _users.length + (_totalPages > 1 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (i >= _users.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: PageNavFooter(
                                page: _page,
                                totalPages: _totalPages,
                                onChanged: _goToPage,
                              ),
                            );
                          }
                          final u = _users[i];
                          return _AdminCard(
                            icon: Icons.person_outline,
                            title: u.fullname,
                            subtitle:
                                '${u.email}\n${u.formCount} form · ${u.responseCount} respons · gabung ${_formatDate(u.createdAt)}',
                            badges: [
                              if (u.role == 'ADMIN')
                                const _Badge('Admin', Color(0xFF6A1B9A)),
                              _Badge(
                                u.isActive ? 'Aktif' : 'Banned',
                                u.isActive
                                    ? kSuccessColor
                                    : kDangerColor,
                              ),
                            ],
                            onTap: () async {
                              await AppRouter.of(context).push(
                                AppPage.adminUserDetail,
                                {'userId': u.id},
                              );
                              _load(page: _page);
                            },
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab Form
// ---------------------------------------------------------------------------
class _AdminFormsTab extends StatefulWidget {
  const _AdminFormsTab();

  @override
  State<_AdminFormsTab> createState() => _AdminFormsTabState();
}

class _AdminFormsTabState extends State<_AdminFormsTab> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _statusFilter = 'all';
  List<AdminFormItem> _forms = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final result = await AdminService.getForms(
        page: page,
        pageSize: _pageSize,
        search: _query,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _forms = result.items;
        _page = page;
        _totalPages = result.total <= 0
            ? 1
            : (result.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPage(int page) {
    if (page == _page || page < 1 || page > _totalPages) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _load(page: page);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: _AdminSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            hint: 'Cari judul, kode link, atau pemilik...',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (value, label) in const [
                  ('all', 'Semua'),
                  ('published', 'Terbit'),
                  ('draft', 'Draft'),
                  ('closed', 'Ditutup'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: () {
                        setState(() => _statusFilter = value);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _statusFilter == value
                              ? kAuthPrimary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: _statusFilter == value
                                ? kAuthPrimary
                                : const Color(0xFFBDC9C8),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _statusFilter == value
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontFamily: _statusFilter == value
                                ? kFontBold
                                : null,
                            color: _statusFilter == value
                                ? Colors.white
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: kAuthPrimary,
            onRefresh: () => _load(),
            child: !_loading && _forms.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.folder_off_outlined,
                                color: Colors.grey, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              _query.isEmpty
                                  ? 'Belum ada form'
                                  : 'Tidak ada hasil untuk "${_searchController.text}"',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount:
                            _forms.length + (_totalPages > 1 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (i >= _forms.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: PageNavFooter(
                                page: _page,
                                totalPages: _totalPages,
                                onChanged: _goToPage,
                              ),
                            );
                          }
                          final f = _forms[i];
                          return _AdminCard(
                            icon: Icons.description_outlined,
                            title: f.title,
                            subtitle:
                                'Oleh ${f.ownerName.isEmpty ? "—" : f.ownerName}\n${f.responseCount} respons · dibuat ${_formatDate(f.createdAt)}',
                            badges: [
                              _Badge(f.status, _statusColor(f.status)),
                              if (f.takenDownAt != null)
                                const _Badge('Taken Down', kDangerColor),
                            ],
                            onTap: () async {
                              await AppRouter.of(context).push(
                                AppPage.adminFormDetail,
                                {'formId': f.id},
                              );
                              _load(page: _page);
                            },
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'published':
      return kSuccessColor;
    case 'closed':
      return kWarningColor;
    default:
      return kInfoColor;
  }
}

// ---------------------------------------------------------------------------
// Tab Feedback
// ---------------------------------------------------------------------------
class _AdminFeedbackTab extends StatefulWidget {
  const _AdminFeedbackTab();

  @override
  State<_AdminFeedbackTab> createState() => _AdminFeedbackTabState();
}

class _AdminFeedbackTabState extends State<_AdminFeedbackTab> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  List<AdminFeedbackItem> _feedbacks = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final result =
          await AdminService.getFeedbacks(page: page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _feedbacks = result.items;
        _page = page;
        _totalPages = result.total <= 0
            ? 1
            : (result.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPage(int page) {
    if (page == _page || page < 1 || page > _totalPages) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _load(page: page);
  }

  Future<void> _actionMenu(AdminFeedbackItem item) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kDangerColor),
              title: const Text('Dismiss Feedback'),
              onTap: () => Navigator.pop(sheetContext, 'dismiss'),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: kWarningColor),
              title: const Text('Takedown Form Terkait'),
              onTap: () => Navigator.pop(sheetContext, 'takedown'),
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: kSuccessColor),
              title: const Text('Restore Form Terkait'),
              onTap: () => Navigator.pop(sheetContext, 'restore'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      switch (choice) {
        case 'dismiss':
          await AdminService.dismissFeedback(item.id);
          if (!mounted) return;
          showAuthToast(context, 'Feedback dihapus');
          break;
        case 'takedown':
          await AdminService.feedbackTakedown(item.id);
          if (!mounted) return;
          showAuthToast(context, 'Form di-takedown');
          break;
        case 'restore':
          await AdminService.feedbackRestore(item.id);
          if (!mounted) return;
          showAuthToast(context, 'Form di-restore');
          break;
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: kAuthPrimary,
            onRefresh: () => _load(),
            child: !_loading && _feedbacks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.forum_outlined,
                                color: Colors.grey, size: 36),
                            SizedBox(height: 10),
                            Text('Belum ada feedback',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount:
                            _feedbacks.length + (_totalPages > 1 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (i >= _feedbacks.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: PageNavFooter(
                                page: _page,
                                totalPages: _totalPages,
                                onChanged: _goToPage,
                              ),
                            );
                          }
                          final f = _feedbacks[i];
                          return _AdminCard(
                            icon: Icons.forum_outlined,
                            title: f.formTitle.isEmpty
                                ? 'Form #${f.formId}'
                                : f.formTitle,
                            subtitle:
                                '${f.userName} (${f.userEmail})\n"${f.reason}"${f.description != null && f.description!.isNotEmpty ? ' — ${f.description}' : ''}',
                            badges: [_formatDate(f.createdAt)],
                            badgeStyle: false,
                            onTap: () async {
                              await AppRouter.of(context).push(
                                AppPage.adminFeedbackDetail,
                                {'feedback': f},
                              );
                              _load();
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black54, size: 20),
                              onPressed: () => _actionMenu(f),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu & badge bersama
// ---------------------------------------------------------------------------
class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<dynamic> badges;
  final bool badgeStyle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.badgeStyle = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kAuthPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final badge in badges)
                          badge is _Badge
                              ? badge
                              : Text(
                                  '$badge',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: color,
        ),
      ),
    );
  }
}
