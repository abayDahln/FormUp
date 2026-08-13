import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'form_card.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Tab "Form" — input kode untuk mengerjakan + daftar "Form Saya" (kelola).
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _codeController = TextEditingController();
  List<FormData> _myForms = [];
  bool _loadingForms = true;
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

  Widget _buildFormCard(FormData form) {
    return FormCard(
      form: form,
      onTap: () => AppRouter.of(context).push(AppPage.formDetail, {
        'formId': form.id,
        'form': form,
      }),
      onQuickActions: () => showFormQuickActions(
        context,
        form,
        onChanged: _refreshMyForms,
      ),
    );
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
                  'Kerjakan via kode atau kelola form Anda',
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
                  'Lihat dan Kelola Form Anda',
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
}
