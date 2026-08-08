import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

class _FormStatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const _FormStatusStyle(this.label, this.fg, this.bg);
}

_FormStatusStyle _formStatusStyle(String status) {
  switch (status) {
    case 'published':
      return const _FormStatusStyle('Terbit', Color(0xFF2E7D32), Color(0xFFE3F4E8));
    case 'draft':
      return const _FormStatusStyle('Draf', Color(0xFFB26A00), Color(0xFFFFF3DE));
    default:
      return const _FormStatusStyle('Ditutup', Color(0xFFC0392B), Color(0xFFFDE8E6));
  }
}

/// Tab "Form" — input kode untuk mengerjakan + daftar "Form Saya" (pratinjau).
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _codeController = TextEditingController();
  List<FormData> _myForms = [];
  bool _loadingForms = true;
  int? _publishingId;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadMyForms();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyForms() async {
    // ponytail: debounce — swipe refresh tidak boleh terlalu sering (2 detik).
    final now = DateTime.now();
    if (now.difference(_lastRefresh) < const Duration(seconds: 2)) return;
    _lastRefresh = now;
    await _refreshMyForms();
  }

  /// Muat ulang tanpa debounce — dipakai setelah aksi (mis. publish).
  Future<void> _refreshMyForms() async {
    setState(() => _loadingForms = true);
    try {
      final forms = await FormService.getMyForms();
      if (!mounted) return;
      setState(() => _myForms = forms);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingForms = false);
    }
  }

  void _start() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    AppRouter.of(context).push(AppPage.formRunner, {'code': code});
  }

  void _openPreview(FormData form) {
    AppRouter.of(context).push(AppPage.formPreview, {'formId': form.id});
  }

  Future<void> _togglePublish(FormData form) async {
    final publish = form.status != 'published';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          publish ? 'Terbitkan Form' : 'Tarik Form',
          style: const TextStyle(fontFamily: kFontBold),
        ),
        content: Text(
          publish
              ? 'Form akan tersedia untuk dikerjakan responden.'
              : 'Form akan berhenti menerima respons baru dan kembali menjadi draf.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              publish ? 'Terbit' : 'Tarik',
              style: const TextStyle(color: kAuthPrimary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishingId = form.id);
    try {
      await FormService.publish(form.id);
      if (!mounted) return;
      showAuthToast(
        context,
        publish ? 'Form berhasil diterbitkan' : 'Form berhasil ditarik',
      );
      await _refreshMyForms();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _publishingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadMyForms,
      color: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kerjakan via kode atau pratinjau form Anda',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Kerjakan dengan kode
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadius),
                boxShadow: softShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Kerjakan Form",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Masukkan kode form untuk mulai mengerjakan.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    style: const TextStyle(color: Colors.black87),
                    cursorColor: kAuthPrimary,
                    decoration: InputDecoration(
                      hintText: "Kode form",
                      hintStyle: const TextStyle(color: kAuthText),
                      prefixIcon: const Icon(Icons.link, color: kAuthText),
                      filled: true,
                      fillColor: const Color(0xFFF0F4F4),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAuthText),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kAuthText),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: kAuthPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _start(),
                  ),
                  const SizedBox(height: 12),
                  AuthPrimaryButton(
                    label: "Mulai",
                    showArrow: false,
                    onPressed: _start,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Saya
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Saya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ketuk untuk pratinjau sebagai responden',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loadingForms && _myForms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myForms.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.description_outlined, color: Colors.grey, size: 36),
                    SizedBox(height: 10),
                    Text(
                      'Belum ada form. Buat form pertama Anda!',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              )
            else
              for (final form in _myForms) ...[
                _buildFormCard(form),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(FormData form) {
    final style = _formStatusStyle(form.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: kAuthPrimary,
                  size: 22,
                ),
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
                    if (form.description != null &&
                        form.description!.trim().isNotEmpty)
                      Text(
                        form.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: style.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: style.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.people_outline,
                          color: Colors.grey,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${form.responseCount} respons',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _publishingId == form.id
                      ? null
                      : () => _togglePublish(form),
                  icon: _publishingId == form.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kAuthPrimary,
                          ),
                        )
                      : Icon(
                          form.status == 'published'
                              ? Icons.visibility_off_outlined
                              : Icons.publish_outlined,
                          size: 16,
                          color: kAuthPrimary,
                        ),
                  label: Text(
                    form.status == 'published' ? 'Tarik' : 'Terbit',
                    style: const TextStyle(fontSize: 13, color: kAuthPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openPreview(form),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: kAuthPrimary,
                  ),
                  label: const Text(
                    "Pratinjau",
                    style: TextStyle(fontSize: 13, color: kAuthPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => AppRouter.of(context).push(
                    AppPage.formResponses,
                    {'formId': form.id, 'title': form.title},
                  ),
                  icon: const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: kAuthPrimary,
                  ),
                  label: const Text(
                    "Respons",
                    style: TextStyle(fontSize: 13, color: kAuthPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
