import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Detail user untuk admin + aksi ban/activate/delete
class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  AdminUserDetail? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await AdminService.getUserDetail(widget.userId);
      if (!mounted) return;
      setState(() => _user = user);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirm(String title, String content, String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: kFontBold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: kAuthPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showAuthToast(context, success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _ban() async {
    final ok = await _confirm(
      'Ban User',
      'User "${_user?.fullname}" tidak akan bisa login lagi.',
      'Ban',
    );
    if (ok == true && mounted) _run(() => AdminService.banUser(widget.userId), 'User di-ban');
  }

  void _activate() async {
    final ok = await _confirm(
      'Aktifkan User',
      'User "${_user?.fullname}" akan bisa login kembali.',
      'Aktifkan',
    );
    if (ok == true && mounted) {
      _run(() => AdminService.activateUser(widget.userId), 'User diaktifkan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final isAdmin = u?.role == 'ADMIN';
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: const Text(
          "Detail User",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator.circular())
          : u == null
              ? const Center(
                  child: Text('Data tidak tersedia.',
                      style: TextStyle(color: Colors.black54)))
              : AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: softShadow(),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: kPrimarySoft,
                              backgroundImage: (u.profileImage ?? '').isNotEmpty
                                  ? CachedNetworkImageProvider(u.profileImage!)
                                  : null,
                              child: (u.profileImage ?? '').isEmpty
                                  ? Text(
                                      u.fullname.isNotEmpty
                                          ? u.fullname[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: kFontBold,
                                        color: kAuthPrimary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              u.fullname,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${u.username ?? '-'}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: [
                                if (isAdmin)
                                  const _DetailBadge(
                                      'Admin', Color(0xFF6A1B9A)),
                                _DetailBadge(
                                  u.isActive ? 'Aktif' : 'Banned',
                                  u.isActive
                                      ? kSuccessColor
                                      : kDangerColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _infoCard([
                        _infoRow(Icons.email_outlined, 'Email', u.email),
                        _infoRow(Icons.cake_outlined, 'Tanggal Lahir',
                            u.birthdate ?? '—'),
                        _infoRow(Icons.description_outlined, 'Jumlah Form',
                            '${u.formCount}'),
                        _infoRow(
                            Icons.people_outline, 'Jumlah Respons',
                            '${u.responseCount}'),
                        _infoRow(Icons.calendar_today_outlined,
                            'Tanggal Gabung', _formatDate(u.createdAt)),
                        if (u.deletedAt != null)
                          _infoRow(Icons.delete_outline, 'Dihapus',
                              _formatDate(u.deletedAt)),
                      ]),
                      if (!isAdmin) ...[
                        const SizedBox(height: 20),
                        if (u.isActive)
                          OutlinedButton(
                            onPressed: _ban,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kWarningColor),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(kRadius)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Ban User',
                                style: TextStyle(
                                    color: kWarningColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: kFontBold)),
                          )
                        else
                          AuthPrimaryButton(
                            label: 'Aktifkan User',
                            pill: true,
                            onPressed: _activate,
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kAuthPrimary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ),
        ],
      ),
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

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: color,
        ),
      ),
    );
  }
}
