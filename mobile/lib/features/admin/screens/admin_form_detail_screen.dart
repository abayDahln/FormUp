import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Detail form untuk admin + aksi takedown/restore, termasuk daftar soal
class AdminFormDetailScreen extends StatefulWidget {
  final int formId;

  const AdminFormDetailScreen({super.key, required this.formId});

  @override
  State<AdminFormDetailScreen> createState() => _AdminFormDetailScreenState();
}

class _AdminFormDetailScreenState extends State<AdminFormDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  AdminFormDetail? _form;
  List<QuestionData> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AdminService.getFormDetail(widget.formId),
        FormService.getQuestions(widget.formId),
      ]);
      if (!mounted) return;
      setState(() {
        _form = results[0] as AdminFormDetail;
        _questions = results[1] as List<QuestionData>;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirm(String title, String content, String action,
      {bool danger = false}) {
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
            child: Text(action,
                style: TextStyle(
                    color: danger ? kDangerColor : kAuthPrimary)),
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

  void _takedown() async {
    final ok = await _confirm(
      'Takedown Form',
      'Form "${_form?.title}" akan disembunyikan dari publik.',
      'Takedown',
    );
    if (ok == true && mounted) {
      _run(() => AdminService.takedownForm(widget.formId), 'Form di-takedown');
    }
  }

  void _restore() async {
    final ok = await _confirm(
      'Restore Form',
      'Form "${_form?.title}" akan bisa diakses publik kembali.',
      'Restore',
    );
    if (ok == true && mounted) {
      _run(() => AdminService.restoreForm(widget.formId), 'Form di-restore');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _form;
    final takenDown = f?.takenDownAt != null;
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
          "Detail Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingOverlay()
          : f == null
              ? const Center(
                  child: Text('Data tidak tersedia.',
                      style: TextStyle(color: Colors.black54)))
              : AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: softShadow(),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((f.bannerImage ?? '').isNotEmpty)
                              AspectRatio(
                                aspectRatio: 3,
                                child: CachedRemoteImage(
                                  url: _resolveUrl(f.bannerImage!),
                                  fit: BoxFit.cover,
                                  errorWidget: const SizedBox.shrink(),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichTextView(
                                    text: f.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: kFontBold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (f.description != null &&
                                      f.description!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    RichTextView(
                                      text: f.description!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      _Badge(_statusLabel(f.status),
                                          _statusColor(f.status)),
                                      if (takenDown)
                                        const _Badge(
                                            'Taken Down', kDangerColor),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _infoCard([
                        _infoRow(Icons.person_outline, 'Pemilik',
                            '${f.owner.fullname ?? '-'} (${f.owner.email ?? '-'})'),
                        _infoRow(Icons.link_outlined, 'Kode Link', f.formLink),
                        _infoRow(Icons.people_outline, 'Jumlah Respon',
                            '${f.responseCount}'),
                        ..._settingRows(f.settings),
                        _infoRow(Icons.calendar_today_outlined, 'Dibuat',
                            _formatDate(f.createdAt)),
                        if (takenDown)
                          _infoRow(Icons.block_outlined, 'Di-takedown',
                              _formatDate(f.takenDownAt)),
                        if (f.deletedAt != null)
                          _infoRow(Icons.delete_outline, 'Dihapus',
                              _formatDate(f.deletedAt)),
                      ]),
                      const SizedBox(height: 16),
                      _buildQuestionsSection(),
                      const SizedBox(height: 16),
                      if (!takenDown && f.deletedAt == null)
                        OutlinedButton(
                          onPressed: _takedown,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kWarningColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadius)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Takedown Form',
                              style: TextStyle(
                                  color: kWarningColor,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: kFontBold)),
                        ),
                      if (takenDown && f.deletedAt == null)
                        AuthPrimaryButton(
                          label: 'Restore Form',
                          pill: true,
                          onPressed: _restore,
                        ),
                    ],
                  ),
                ),
    );
  }

  /// Daftar pertanyaan form (read-only untuk admin)
  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pertanyaan (${_questions.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
            child: const Text(
              'Form ini belum memiliki soal.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          )
        else
          for (var i = 0; i < _questions.length; i++) ...[
            _QuestionCard(index: i, question: _questions[i]),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<Widget> _settingRows(Map<String, dynamic>? settings) {
    if (settings == null) return [];
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      rows.add(_infoRow(icon, label, value));
    }

    final type = settings['formTypeId'];
    if (type != null) {
      add(Icons.category_outlined, 'Tipe Form',
          type == 2 ? 'Ujian' : 'Formulir');
    }
    if (settings['timerDuration'] != null) {
      add(Icons.timer_outlined, 'Timer', '${settings['timerDuration']} menit');
    }
    if (settings['showScore'] is bool) {
      add(Icons.leaderboard_outlined, 'Tampilkan Nilai',
          settings['showScore'] ? 'Ya' : 'Tidak');
    }
    if (settings['oneResponse'] is bool) {
      add(Icons.filter_1_outlined, 'Satu Respon',
          settings['oneResponse'] ? 'Ya' : 'Tidak');
    }
    final close = settings['closeFormTime'];
    if (close is String && close.isNotEmpty) {
      add(Icons.event_busy_outlined, 'Ditutup', _formatDate(DateTime.tryParse(close)));
    }
    return rows;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'Terbit';
      case 'closed':
        return 'Ditutup';
      default:
        return 'Draft';
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base$path';
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

/// Kartu satu pertanyaan (read-only): nomor, tipe, teks soal, opsi
class _QuestionCard extends StatelessWidget {
  final int index;
  final QuestionData question;

  const _QuestionCard({required this.index, required this.question});

  String get _typeLabel =>
      questionTypes[question.typeId]?.$1 ?? 'Tipe ${question.typeId}';

  @override
  Widget build(BuildContext context) {
    final q = question;
    final options = q.options;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: kPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: kAuthPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichTextView(
                  text: q.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _chip(_typeLabel),
              if (q.isRequired == true) _chip('Wajib dijawab'),
              if (q.correctAnswer != null && q.correctAnswer!.isNotEmpty)
                _chip('Kunci: ${q.correctAnswer}'),
            ],
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${String.fromCharCode(65 + i)}. ${options[i].optionText}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: kAuthPrimary),
      ),
    );
  }
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

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

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
