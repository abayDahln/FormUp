import 'dart:async';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Detail form untuk admin: Info + Soal (paginated) + Respon (paginated) + Feedback (paginated)
class AdminFormDetailScreen extends StatefulWidget {
  final int formId;

  const AdminFormDetailScreen({super.key, required this.formId});

  @override
  State<AdminFormDetailScreen> createState() => _AdminFormDetailScreenState();
}

class _AdminFormDetailScreenState extends State<AdminFormDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _busy = false;
  AdminFormDetail? _form;

  // --- Soal ---
  static const _pageSize = 10;
  List<QuestionData> _questions = [];
  int _qPage = 1, _qTotal = 0, _qTotalPages = 1;
  bool _qLoading = false;
  String _qQuery = '';
  final _qSearchCtrl = TextEditingController();
  Timer? _qDebounce;

  // --- Respon ---
  List<ResponseListItemData> _responses = [];
  int _rPage = 1, _rTotal = 0, _rTotalPages = 1;
  bool _rLoading = false;
  String _rQuery = '';
  final _rSearchCtrl = TextEditingController();
  Timer? _rDebounce;

  // --- Feedback ---
  List<FormFeedbackItem> _feedbacks = [];
  int _fPage = 1, _fTotal = 0, _fTotalPages = 1;
  bool _fLoading = false;
  String _fQuery = '';
  final _fSearchCtrl = TextEditingController();
  Timer? _fDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadForm();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _qDebounce?.cancel();
    _rDebounce?.cancel();
    _fDebounce?.cancel();
    _qSearchCtrl.dispose();
    _rSearchCtrl.dispose();
    _fSearchCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      switch (_tabController.index) {
        case 1:
          if (_questions.isEmpty && !_qLoading) _loadQuestions(page: 1);
          break;
        case 2:
          if (_responses.isEmpty && !_rLoading) _loadResponses(page: 1);
          break;
        case 3:
          if (_feedbacks.isEmpty && !_fLoading) _loadFeedbacks(page: 1);
          break;
      }
    }
  }

  Future<void> _loadForm() async {
    setState(() => _loading = true);
    try {
      final f = await AdminService.getFormDetail(widget.formId);
      if (!mounted) return;
      setState(() => _form = f);
      // preload soal tab pertama kali admin buka tab Soal saja, tapi siapkan total
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- Soal paginated ----
  Future<void> _loadQuestions({int page = 1}) async {
    setState(() => _qLoading = true);
    try {
      final res = await FormService.getQuestionsPaged(
        widget.formId,
        page: page,
        pageSize: _pageSize,
        search: _qQuery,
      );
      if (!mounted) return;
      setState(() {
        _questions = res.items;
        _qPage = page;
        _qTotal = res.total;
        _qTotalPages = res.total <= 0 ? 1 : (res.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _qLoading = false);
    }
  }

  void _onQSearch(String v) {
    _qDebounce?.cancel();
    _qDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _qQuery = v.trim());
      _loadQuestions(page: 1);
    });
  }

  // ---- Respon paginated ----
  Future<void> _loadResponses({int page = 1}) async {
    setState(() => _rLoading = true);
    try {
      final res = await FormService.getResponses(
        widget.formId,
        page: page,
        pageSize: _pageSize,
        search: _rQuery,
      );
      if (!mounted) return;
      setState(() {
        _responses = res.items;
        _rPage = page;
        _rTotal = res.total;
        _rTotalPages = res.total <= 0 ? 1 : (res.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _rLoading = false);
    }
  }

  void _onRSearch(String v) {
    _rDebounce?.cancel();
    _rDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _rQuery = v.trim());
      _loadResponses(page: 1);
    });
  }

  // ---- Feedback paginated ----
  Future<void> _loadFeedbacks({int page = 1}) async {
    setState(() => _fLoading = true);
    try {
      final res = await FormService.getFormFeedbacksPaged(
        widget.formId,
        page: page,
        pageSize: _pageSize,
        search: _fQuery,
      );
      if (!mounted) return;
      setState(() {
        _feedbacks = res.items;
        _fPage = page;
        _fTotal = res.total;
        _fTotalPages = res.total <= 0 ? 1 : (res.total / _pageSize).ceil();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _fLoading = false);
    }
  }

  void _onFSearch(String v) {
    _fDebounce?.cancel();
    _fDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _fQuery = v.trim());
      _loadFeedbacks(page: 1);
    });
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
      await _loadForm();
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 12),
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Soal'),
            Tab(text: 'Respon'),
            Tab(text: 'Feedback'),
          ],
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
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInfoTab(f, takenDown),
                      _buildQuestionsTab(),
                      _buildResponsesTab(),
                      _buildFeedbackTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoTab(AdminFormDetail f, bool takenDown) {
    return ListView(
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
    );
  }

  Widget _buildQuestionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: AppSearchField(
            controller: _qSearchCtrl,
            onChanged: _onQSearch,
            hint: 'Cari soal...',
            historyKey: 'search_admin_q_${widget.formId}',
          ),
        ),
        Expanded(
          child: _qLoading
              ? const AppLoadingOverlay()
              : _questions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _qQuery.isEmpty
                              ? 'Form ini belum memiliki soal.'
                              : 'Tidak ada soal untuk "$_qQuery"',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: _questions.length + (_qTotalPages > 1 ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= _questions.length) {
                          return _PageNav(
                            page: _qPage,
                            totalPages: _qTotalPages,
                            total: _qTotal,
                            onChanged: (p) => _loadQuestions(page: p),
                          );
                        }
                        return _QuestionCard(index: (_qPage - 1) * _pageSize + i, question: _questions[i]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildResponsesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: AppSearchField(
            controller: _rSearchCtrl,
            onChanged: _onRSearch,
            hint: 'Cari responden...',
            historyKey: 'search_admin_r_${widget.formId}',
          ),
        ),
        Expanded(
          child: _rLoading
              ? const AppLoadingOverlay()
              : _responses.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _rQuery.isEmpty
                              ? 'Belum ada respon untuk form ini.'
                              : 'Tidak ada respon untuk "$_rQuery"',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: _responses.length + (_rTotalPages > 1 ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= _responses.length) {
                          return _PageNav(
                            page: _rPage,
                            totalPages: _rTotalPages,
                            total: _rTotal,
                            onChanged: (p) => _loadResponses(page: p),
                          );
                        }
                        final r = _responses[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kRadius),
                            boxShadow: softShadow(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: kAuthPrimary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.respondentName ?? 'Anonim',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatDate(r.submittedAt)} • ${r.status}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              Text('#${r.id}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFeedbackTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: AppSearchField(
            controller: _fSearchCtrl,
            onChanged: _onFSearch,
            hint: 'Cari feedback...',
            historyKey: 'search_admin_f_${widget.formId}',
          ),
        ),
        Expanded(
          child: _fLoading
              ? const AppLoadingOverlay()
              : _feedbacks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _fQuery.isEmpty
                              ? 'Belum ada feedback untuk form ini.'
                              : 'Tidak ada feedback untuk "$_fQuery"',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      itemCount: _feedbacks.length + (_fTotalPages > 1 ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= _feedbacks.length) {
                          return _PageNav(
                            page: _fPage,
                            totalPages: _fTotalPages,
                            total: _fTotal,
                            onChanged: (p) => _loadFeedbacks(page: p),
                          );
                        }
                        final fb = _feedbacks[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(kRadius),
                            boxShadow: softShadow(),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(fb.userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: kPrimarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(fb.reason,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: kAuthPrimary)),
                                  ),
                                ],
                              ),
                              if (fb.description != null && fb.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(fb.description!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              ],
                              const SizedBox(height: 6),
                              Text(_formatDate(fb.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
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
      final sec = settings['timerDuration'] is int ? settings['timerDuration'] as int : int.tryParse('${settings['timerDuration']}') ?? 0;
      add(Icons.timer_outlined, 'Timer', _formatDuration(sec));
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

  String _formatDuration(int sec) {
    if (sec <= 0) return '—';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) return '${m}m ${s}d';
    if (m > 0) return '${m} menit';
    return '${s} detik';
  }
}

class _PageNav extends StatelessWidget {
  final int page, totalPages, total;
  final ValueChanged<int> onChanged;
  const _PageNav({required this.page, required this.totalPages, required this.total, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          Text('$total data • Halaman $page dari $totalPages', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: page > 1 ? () => onChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 22),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: page < totalPages ? () => onChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 22),
              ),
            ],
          ),
        ],
      ),
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
