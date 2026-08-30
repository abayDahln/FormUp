import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Poin 12 hardening: whitelist host gambar banner template — cegah load URL sembarang.
bool _isAllowedBannerUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || !(uri.scheme == 'https' || uri.scheme == 'http')) return false;
  const allowedHosts = {'images.unsplash.com', 'plus.unsplash.com'};
  return allowedHosts.contains(uri.host.toLowerCase());
}

/// Data template — 1:1 dengan `web/form-fe/src/features/dashboard/userDashboard/templateForm.jsx:13` TEMPLATES.
/// API belum menyediakan `GET /api/templates` (lihat `api/documentation/endpoints/planned.md:9`),
/// jadi template didefinisikan lokal seperti web (frontend-only). Sinkron judul/deskripsi/soal/pengaturan.
class FormTemplate {
  final String id;
  final String title;
  final String category;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final int questionCount;
  final String description;
  final String bannerImage;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> questions;

  const FormTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.questionCount,
    required this.description,
    required this.bannerImage,
    required this.settings,
    required this.questions,
  });
}

const _kTemplates = [
  FormTemplate(
    id: 'tpl-umum',
    title: 'Formulir Pendaftaran & Survei Umum',
    category: 'Form Umum',
    icon: Icons.description_outlined,
    iconBg: Color(0xFFE0F2F1),
    iconColor: Color(0xFF00897B),
    questionCount: 6,
    description: 'Templat serbaguna seperti Google Form dengan urutan soal teracak untuk biodata, jenis kelamin, hobi, dan kritik/saran.',
    bannerImage: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800&auto=format&fit=crop&q=80',
    settings: {'randomizeQuestions': true, 'formTypeId': 1, 'showScore': false, 'oneResponse': false, 'requiredLogin': false},
    questions: [
      {'typeId': 1, 'question': 'Nama Lengkap', 'isRequired': true, 'options': []},
      {'typeId': 1, 'question': 'Alamat Email', 'isRequired': true, 'options': []},
      {'typeId': 1, 'question': 'Nomor Telepon / WhatsApp', 'isRequired': true, 'options': []},
      {'typeId': 2, 'question': 'Jenis Kelamin', 'isRequired': true, 'options': [{'optionText': 'Laki-laki'}, {'optionText': 'Perempuan'}]},
      {'typeId': 3, 'question': 'Hobi & Minat', 'isRequired': false, 'options': [{'optionText': 'Membaca Buku'}, {'optionText': 'Olahraga & Kebugaran'}, {'optionText': 'Musik & Kesenian'}, {'optionText': 'Teknologi & Koding'}]},
      {'typeId': 1, 'question': 'Kritik dan Saran untuk Peningkatan Layanan Kami', 'isRequired': false, 'options': []},
    ],
  ),
  FormTemplate(
    id: 'tpl-ujian-pg',
    title: 'Ujian Pilihan Ganda & Kuis Akademik',
    category: 'Ujian PG',
    icon: Icons.check_circle_outline,
    iconBg: Color(0xFFE3F2FD),
    iconColor: Color(0xFF1565C0),
    questionCount: 3,
    description: 'Ujian PG resmi: Timer 30 menit, Batasi 1 respons, Wajib login. Skor otomatis tampil.',
    bannerImage: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80',
    settings: {'timerDuration': 1800, 'oneResponse': true, 'requiredLogin': true, 'showScore': true, 'randomizeQuestions': true, 'formTypeId': 2},
    questions: [
      {'typeId': 2, 'question': 'Apa nama ibu kota negara Indonesia yang baru yang berlokasi di Kalimantan Timur?', 'isRequired': true, 'correctAnswer': 'Nusantara', 'options': [{'optionText': 'Nusantara', 'isCorrect': true}, {'optionText': 'Jakarta'}, {'optionText': 'Balikpapan'}, {'optionText': 'Samarinda'}]},
      {'typeId': 2, 'question': 'Berapakah hasil dari 10 + 5?', 'isRequired': true, 'correctAnswer': '15', 'options': [{'optionText': '15', 'isCorrect': true}, {'optionText': '12'}, {'optionText': '20'}, {'optionText': '25'}]},
      {'typeId': 2, 'question': 'Manakah planet terbesar di dalam tata surya kita?', 'isRequired': true, 'correctAnswer': 'Yupiter', 'options': [{'optionText': 'Yupiter', 'isCorrect': true}, {'optionText': 'Saturnus'}, {'optionText': 'Bumi'}, {'optionText': 'Mars'}]},
    ],
  ),
  FormTemplate(
    id: 'tpl-matematika',
    title: 'Kuis & Latihan Soal Matematika',
    category: 'Matematika',
    icon: Icons.calculate_outlined,
    iconBg: Color(0xFFF3E5F5),
    iconColor: Color(0xFF6A1B9A),
    questionCount: 4,
    description: 'Soal matematika dengan rumus KaTeX: kuadratik, integral, limit, dan Pythagoras.',
    bannerImage: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&auto=format&fit=crop&q=80',
    settings: {'showScore': true, 'randomizeQuestions': true, 'formTypeId': 1, 'oneResponse': false, 'requiredLogin': false},
    questions: [
      {'typeId': 2, 'question': '<p>Tentukan himpunan penyelesaian dari persamaan kuadrat berikut jika \$\$a = 1, b = -5, c = 6\$\$ menggunakan rumus kuadratik:</p><p>\$\$x = \\\\frac{-b \\\\pm \\\\sqrt{b^2 - 4ac}}{2a}\$\$</p>', 'isRequired': true, 'correctAnswer': 'x = 2 dan x = 3', 'options': [{'optionText': 'x = 2 dan x = 3', 'isCorrect': true}, {'optionText': 'x = -2 dan x = -3'}, {'optionText': 'x = 1 dan x = 6'}, {'optionText': 'x = -1 dan x = 5'}]},
      {'typeId': 2, 'question': '<p>Berapakah hasil evaluasi dari integral tentu berikut?</p><p>\$\$\\\\int_{0}^{2} 3x^2 \\\\, dx\$\$</p>', 'isRequired': true, 'correctAnswer': '8', 'options': [{'optionText': '8', 'isCorrect': true}, {'optionText': '6'}, {'optionText': '12'}, {'optionText': '4'}]},
      {'typeId': 2, 'question': '<p>Hitunglah nilai limit fungsi trigonometri berikut:</p><p>\$\$\\\\lim_{x \\\\to 0} \\\\frac{\\\\sin(2x)}{x}\$\$</p>', 'isRequired': true, 'correctAnswer': '2', 'options': [{'optionText': '2', 'isCorrect': true}, {'optionText': '0'}, {'optionText': '1'}, {'optionText': 'Tak Hingga (\\\\infty)'}]},
      {'typeId': 2, 'question': '<p>Diketahui segitiga siku-siku dengan panjang sisi tegak \$\$a = 6\\\\text{ cm}\$\$ dan \$\$b = 8\\\\text{ cm}\$\$. Berapakah panjang sisi miring (\$\$c\$\$) berdasarkan teorema Pythagoras \$\$a^2 + b^2 = c^2\$\$?</p>', 'isRequired': true, 'correctAnswer': '10 cm', 'options': [{'optionText': '10 cm', 'isCorrect': true}, {'optionText': '12 cm'}, {'optionText': '14 cm'}, {'optionText': '15 cm'}]},
    ],
  ),
  FormTemplate(
    id: 'tpl-coding',
    title: 'Tes Kompetensi Pemrograman & Koding',
    category: 'Koding',
    icon: Icons.code_outlined,
    iconBg: Color(0xFFE8F5E9),
    iconColor: Color(0xFF2E7D32),
    questionCount: 4,
    description: 'Tes koding: JavaScript map/filter, rekursi Python, Stack LIFO, dan SQL COUNT(*).',
    bannerImage: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80',
    settings: {'showScore': true, 'oneResponse': true, 'timerDuration': 2700, 'formTypeId': 1, 'randomizeQuestions': false, 'requiredLogin': false},
    questions: [
      {'typeId': 2, 'question': '<p>Perhatikan potongan kode JavaScript berikut:</p><pre><code class="language-javascript">const numbers = [1, 2, 3, 4];\\nconst result = numbers.map(n => n * 2).filter(n => n > 4);\\nconsole.log(result);</code></pre><p>Apakah output yang dicetak ke console?</p>', 'isRequired': true, 'correctAnswer': '[6, 8]', 'options': [{'optionText': '[6, 8]', 'isCorrect': true}, {'optionText': '[4, 6, 8]'}, {'optionText': '[2, 4, 6, 8]'}, {'optionText': '[8]'}]},
      {'typeId': 2, 'question': '<p>Perhatikan fungsi rekursif Python berikut:</p><pre><code class="language-python">def faktorial(n):\\n    if n <= 1:\\n        return 1\\n    return n * faktorial(n - 1)\\n\\nprint(faktorial(4))</code></pre><p>Berapakah nilai yang dihasilkan?</p>', 'isRequired': true, 'correctAnswer': '24', 'options': [{'optionText': '24', 'isCorrect': true}, {'optionText': '12'}, {'optionText': '16'}, {'optionText': '4'}]},
      {'typeId': 2, 'question': '<p>Dalam struktur data, operasi <code>push()</code> dan <code>pop()</code> pada Stack mengikuti prinsip apa?</p>', 'isRequired': true, 'correctAnswer': 'LIFO (Last In, First Out)', 'options': [{'optionText': 'LIFO (Last In, First Out)', 'isCorrect': true}, {'optionText': 'FIFO (First In, First Out)'}, {'optionText': 'LILO (Last In, Last Out)'}, {'optionText': 'Random Access'}]},
      {'typeId': 2, 'question': '<p>Perhatikan query SQL:</p><pre><code class="language-sql">SELECT COUNT(*) FROM users WHERE status = \'active\';</code></pre><p>Apa fungsi <code>COUNT(*)</code>?</p>', 'isRequired': true, 'correctAnswer': 'Menghitung total baris pengguna yang berstatus aktif', 'options': [{'optionText': 'Menghitung total baris pengguna yang berstatus aktif', 'isCorrect': true}, {'optionText': 'Mengambil seluruh kolom tabel users'}, {'optionText': 'Menjumlahkan nilai kolom status'}, {'optionText': 'Menghapus data user yang aktif'}]},
    ],
  ),
];

/// Pilih template saat buat form — mirror `web/.../templateForm.jsx`.
class FormTemplateChooserScreen extends StatefulWidget {
  const FormTemplateChooserScreen({super.key});

  @override
  State<FormTemplateChooserScreen> createState() => _FormTemplateChooserScreenState();
}

class _FormTemplateChooserScreenState extends State<FormTemplateChooserScreen> {
  String? _cloningId;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FormTemplate> get _filtered {
    if (_query.trim().isEmpty) return _kTemplates;
    final q = _query.toLowerCase();
    return _kTemplates.where((t) => t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q) || t.category.toLowerCase().contains(q)).toList();
  }

  Future<void> _useTemplate(FormTemplate tpl) async {
    if (!AppDebouncer.tryAcquire('form:useTemplate')) return;
    if (_cloningId != null) return;
    setState(() => _cloningId = tpl.id);
    try {
      final formId = await FormService.createForm(title: tpl.title, description: tpl.description);
      if (tpl.settings.isNotEmpty) {
        await FormService.updateSettings(formId, tpl.settings);
      }
      if (tpl.questions.isNotEmpty) {
        final payload = [
          for (var i = 0; i < tpl.questions.length; i++)
            {
              'typeId': tpl.questions[i]['typeId'],
              'question': tpl.questions[i]['question'],
              'questionFormat': 'html',
              'questionOrder': i + 1,
              'isRequired': tpl.questions[i]['isRequired'] ?? true,
              'correctAnswer': tpl.questions[i]['correctAnswer'],
              'options': [
                for (var j = 0; j < (tpl.questions[i]['options'] as List).length; j++)
                  {'optionText': (tpl.questions[i]['options'][j] as Map)['optionText'] ?? '', 'isCorrect': (tpl.questions[i]['options'][j] as Map)['isCorrect'] == true, 'optionOrder': j + 1},
              ],
            },
        ];
        await FormService.saveQuestions(formId, payload);
      }
      formsVersion.value++;
      if (!mounted) return;
      // Ganti chooser dengan detail form — user bisa langsung edit/lanjut kelola soal.
      AppRouter.of(context).replaceTop(AppPage.formDetail, {'formId': formId});
      showAuthToast(context, 'Form dari template "${tpl.title}" berhasil dibuat');
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _cloningId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        title: const Text('Pilih Template'),
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 18), onPressed: () => AppRouter.of(context).pop()),
      ),
      body: AuthBackground(plain: true,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Buat Form Baru', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    const Text('Mulai dari form kosong atau gunakan template siap pakai (soal & pengaturan otomatis terisi).', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: formUpInputDecoration(hintText: 'Cari template...', prefixIcon: const Icon(Icons.search, size: 18)).copyWith(
                        filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _EmptyFormCard(
                    onTap: _cloningId != null ? null : () => AppRouter.of(context).push(AppPage.formMaker),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    const Text('Galeri Template', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kAuthPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text('${filtered.length} template', style: const TextStyle(fontSize: 11, color: kAuthPrimary, fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),
              if (filtered.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(child: Center(child: Text('Tidak ada template untuk "$_query"', style: const TextStyle(color: Colors.black54)))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final tpl = filtered[i];
                      final cloning = _cloningId == tpl.id;
                      return _TemplateCard(template: tpl, cloning: cloning, busy: _cloningId != null, onUse: () => _useTemplate(tpl));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFormCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptyFormCard({this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: kAuthPrimary.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(kRadiusLg)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kAuthPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.note_add_outlined, color: kAuthPrimary)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Form Kosong', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)), SizedBox(height: 2), Text('Buat form baru dari kosong', style: TextStyle(fontSize: 11, color: Colors.black54))])),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;
  final bool cloning;
  final bool busy;
  final VoidCallback onUse;
  const _TemplateCard({required this.template, required this.cloning, required this.busy, required this.onUse});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(kRadiusLg), border: Border.all(color: const Color(0xFFE0E0E0))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 132,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            _isAllowedBannerUrl(template.bannerImage)
                ? CachedNetworkImage(
                    imageUrl: template.bannerImage,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    maxWidthDiskCache: 800,
                    placeholder: (_, _) => Container(color: template.iconBg, child: const Center(child: SizedBox(width: 20, height: 20, child: AppLoadingIndicator.inline()))),
                    errorWidget: (_, _, _) => Container(color: template.iconBg, child: Icon(template.icon, color: template.iconColor.withValues(alpha: 0.5))),
                  )
                : Container(color: template.iconBg, child: Icon(template.icon, color: template.iconColor.withValues(alpha: 0.5))),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99000000)]))),
            Positioned(
              bottom: 10, left: 12, right: 12,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)), child: Text(template.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: kFontBold))),
                Row(children: [const Icon(Icons.help_outline, size: 14, color: Colors.white), const SizedBox(width: 4), Text('${template.questionCount} Soal', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))]),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: template.iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(template.icon, size: 18, color: template.iconColor)),
              const SizedBox(width: 8),
              Expanded(child: Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(template.description, style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onUse,
                icon: cloning ? const SizedBox(width: 14, height: 14, child: AppLoadingIndicator.button()) : const Icon(Icons.arrow_forward, size: 16),
                label: Text(cloning ? 'Menyiapkan...' : 'Gunakan Template Ini', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: kAuthPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
