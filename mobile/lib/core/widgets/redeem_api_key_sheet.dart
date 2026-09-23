import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/core/services/api_key_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/responsive.dart';

/// Bottom sheet "Dapatkan API Key": user memasukkan kode/PW redeem, server
/// mengembalikan API key Gemini bila kode cocok (wajib login).
/// Sukses → opsi Salin dan Terapkan langsung (disimpan via GeminiService).
///
/// Mengembalikan true bila user menekan Terapkan (pemanggil sebaiknya
/// refresh tampilan key-nya). Pola sheet mengikuti UserGuideSheet
/// (DraggableScrollableSheet + selfScrolling) agar aman di phone maupun
/// dialog tablet/desktop (Windows).
class RedeemApiKeySheet extends StatefulWidget {
  final ScrollController scrollController;

  const RedeemApiKeySheet({super.key, required this.scrollController});

  /// Tampilkan sheet. Return true jika API key diterapkan.
  static Future<bool> show(BuildContext context) async {
    final applied = await AdaptiveSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      selfScrolling: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, controller) =>
            RedeemApiKeySheet(scrollController: controller),
      ),
    );
    return applied == true;
  }

  @override
  State<RedeemApiKeySheet> createState() => _RedeemApiKeySheetState();
}

class _RedeemApiKeySheetState extends State<RedeemApiKeySheet> {
  final _codeCtrl = TextEditingController();
  bool _obscureCode = true;
  bool _redeeming = false;
  String? _error;
  RedeemedApiKey? _result;
  bool _obscureKey = true;
  bool _applying = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Kode tidak boleh kosong.');
      return;
    }
    setState(() {
      _redeeming = true;
      _error = null;
    });
    try {
      final result = await ApiKeyService.redeemApiKey(code);
      if (!mounted) return;
      setState(() {
        _result = result;
        _redeeming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.errorMessage(e);
        _redeeming = false;
      });
    }
  }

  Future<void> _copy() async {
    final key = _result?.apiKey ?? '';
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    showAuthToast(context, 'API Key disalin ke clipboard');
  }

  Future<void> _apply() async {
    final key = _result?.apiKey ?? '';
    if (key.isEmpty || _applying) return;
    setState(() => _applying = true);
    try {
      await GeminiService.setUserKey(key);
      if (!mounted) return;
      showAuthToast(context, 'API Key diterapkan');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _applying = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dapatkan API Key',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _result == null
                ? 'Masukkan kode dari guru/admin kelasmu'
                : 'Kode cocok! Simpan baik-baik key ini',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: _result == null ? _codeForm(cs) : _resultView(cs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeCtrl,
          obscureText: _obscureCode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redeem(),
          decoration: InputDecoration(
            labelText: 'Kode redeem',
            hintText: 'Kode Redeem',
            border: const OutlineInputBorder(),
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: _obscureCode ? 'Tampilkan' : 'Sembunyikan',
              onPressed: () =>
                  setState(() => _obscureCode = !_obscureCode),
              icon: Icon(
                _obscureCode ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Satu kode bisa dipakai banyak teman sekelasmu.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: 'Tebus Kode',
          loading: _redeeming,
          showArrow: false,
          onPressed: _redeeming ? null : _redeem,
        ),
      ],
    );
  }

  Widget _resultView(ColorScheme cs) {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.label != null && result.label!.isNotEmpty
                      ? 'Key "${result.label}" berhasil ditebus'
                      : 'Kode cocok, key berhasil ditebus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.key, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _obscureKey ? '••••••••••••••••' : result.apiKey,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: _obscureKey ? 'Tampilkan' : 'Sembunyikan',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copy,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                ),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Salin'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthPrimaryButton(
                label: 'Terapkan',
                loading: _applying,
                showArrow: false,
                onPressed: _applying ? null : _apply,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
