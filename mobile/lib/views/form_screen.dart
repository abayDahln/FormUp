import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../app_router.dart';

/// Item form yang tampil di layar "My Forms".
///
/// Struktur sengaja disamakan dengan response `GET /api/forms` agar mudah
/// dihubungkan ke backend nanti (id, title, description, status, responseCount).
class _FormItem {
  final String title;
  final String description;
  final String status; // 'published' | 'draft' | 'closed'
  final int responses;
  final String time;
  final IconData icon;
  final Color color;

  const _FormItem({
    required this.title,
    required this.description,
    required this.status,
    required this.responses,
    required this.time,
    required this.icon,
    required this.color,
  });
}

// Contoh data (placeholder) — tampilan jadi tetap bagus sebelum backend tersambung.
const List<_FormItem> _demoForms = [
  _FormItem(
    title: 'Survey Kepuasan Pelanggan',
    description: 'Kumpulkan feedback untuk meningkatkan layanan kami.',
    status: 'published',
    responses: 128,
    time: '2 jam lalu',
    icon: Icons.poll_outlined,
    color: Color(0xFF2A9D8F),
  ),
  _FormItem(
    title: 'Pendaftaran Workshop Q4',
    description: 'Formulir registrasi peserta workshop internal.',
    status: 'draft',
    responses: 0,
    time: 'kemarin',
    icon: Icons.event_outlined,
    color: Color(0xFFF2994A),
  ),
  _FormItem(
    title: 'Kuis Pemahaman Materi',
    description: 'Evaluasi pemahaman peserta setelah pelatihan.',
    status: 'closed',
    responses: 45,
    time: '3 hari lalu',
    icon: Icons.quiz_outlined,
    color: Color(0xFF9B51E0),
  ),
  _FormItem(
    title: 'Feedback Event Tahunan',
    description: 'Masukan dari peserta acara tahunan perusahaan.',
    status: 'published',
    responses: 267,
    time: '1 minggu lalu',
    icon: Icons.rate_review_outlined,
    color: Color(0xFFEB5757),
  ),
];

class _StatusStyle {
  final String label;
  final Color fg;
  final Color bg;

  const _StatusStyle(this.label, this.fg, this.bg);
}

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'published':
      return const _StatusStyle('Terbit', Color(0xFF2E7D32), Color(0xFFE3F4E8));
    case 'draft':
      return const _StatusStyle('Draf', Color(0xFFB26A00), Color(0xFFFFF3DE));
    default:
      return const _StatusStyle('Ditutup', Color(0xFFC0392B), Color(0xFFFDE8E6));
  }
}

class FormScreen extends StatelessWidget {
  const FormScreen({super.key});

  void _showFormActions(BuildContext context, _FormItem form) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDC9C8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: form.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(form.icon, color: form.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${form.responses} respons',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 6),
            _SheetAction(
              icon: Icons.edit_outlined,
              label: 'Edit Form',
              onTap: () {
                Navigator.pop(sheetContext);
                AppRouter.of(context).push(AppPage.formMaker);
              },
            ),
            _SheetAction(
              icon: Icons.people_outline,
              label: 'Lihat Respons',
              onTap: () {
                Navigator.pop(sheetContext);
                showAuthToast(context, 'Respons form akan segera hadir');
              },
            ),
            _SheetAction(
              icon: Icons.dashboard_customize_outlined,
              label: 'Analitik',
              onTap: () {
                Navigator.pop(sheetContext);
                showAuthToast(context, 'Analitik akan segera hadir');
              },
            ),
            _SheetAction(
              icon: Icons.ios_share,
              label: 'Bagikan Form',
              isCopy: true,
              onTap: () {
                Navigator.pop(sheetContext);
                showAuthToast(context, 'Link form disalin');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<_FormItem> forms) {
    final published = forms.where((f) => f.status == 'published').length;
    final drafts = forms.where((f) => f.status == 'draft').length;
    final closed = forms.where((f) => f.status == 'closed').length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Terbit',
            value: '$published',
            color: const Color(0xFF2A9D8F),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Draf',
            value: '$drafts',
            color: const Color(0xFFF2994A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Ditutup',
            value: '$closed',
            color: const Color(0xFFC0392B),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, _FormItem form) {
    final style = _statusStyle(form.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: () => _showFormActions(context, form),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: form.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(form.icon, color: form.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            form.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            form.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: style.fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.people_outline, color: Colors.grey, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${form.responses}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      form.time,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Form Saya',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kelola dan pantau semua form Anda',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8E2DE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_outlined, color: kAuthPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsRow(_demoForms),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: softShadow(),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Cari form...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Form Anda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            for (final form in _demoForms) _buildFormCard(context, form),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.circle, color: color, size: 10),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isCopy;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCopy = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: isCopy ? kAuthPrimary : Colors.black54, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
      onTap: onTap,
    );
  }
}

