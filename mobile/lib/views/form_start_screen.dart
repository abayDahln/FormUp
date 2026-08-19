import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/public_form_service.dart';
import '../app_router.dart';

/// Screen awal form - muncul sebelum masuk ke screen kerjakan form
/// Menampilkan: judul, deskripsi, banner, total soal, timer, token, jam buka/tutup, tombol Mulai
class FormStartScreen extends StatefulWidget {
  final String formLink;

  const FormStartScreen({super.key, required this.formLink});

  @override
  State<FormStartScreen> createState() => _FormStartScreenState();
}

class _FormStartScreenState extends State<FormStartScreen> {
  bool _loading = true;
  String? _error;
  PublicFormInfo? _formInfo;
  bool _validatingToken = false;
  String? _tokenError;

  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(() {
      if (_tokenError != null) setState(() => _tokenError = null);
    });
    _loadFormInfo();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadFormInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await PublicFormService.getFormInfo(widget.formLink);

      // Cek apakah pemilik
      if (info.isOwner && mounted) {
        setState(() {
          _error = "Anda tidak dapat mengisi form yang Anda buat sendiri";
          _loading = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _formInfo = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _startForm() async {
    final info = _formInfo!;

    // Validasi token jika diperlukan
    if (info.requiresToken) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        setState(() => _tokenError = "Masukkan token akses form");
        return;
      }

      setState(() {
        _validatingToken = true;
        _tokenError = null;
      });

      try {
        await PublicFormService.getQuestions(widget.formLink, token: token);
        if (!mounted) return;
        setState(() => _validatingToken = false);
        _showConfirmDialog();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _validatingToken = false;
          _tokenError = AuthService.errorMessage(e);
        });
      }
      return;
    }

    _showConfirmDialog();
  }

  /// Dialog konfirmasi sebelum mulai mengerjakan form
  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Mulai Mengerjakan?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          "Apakah Anda yakin ingin memulai pengerjaan form ini?",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Batal",
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAuthPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              AppRouter.of(context).push(AppPage.formRunner, {
                'code': widget.formLink,
                'token': _tokenController.text.trim(),
              });
            },
            child: const Text("Ya, Mulai"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: kAuthBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Informasi Form",
          style: TextStyle(fontFamily: kFontBold, color: Colors.black87),
        ),
      ),
      body: AuthBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFC0392B)),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: "Kembali",
                onPressed: () => AppRouter.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final info = _formInfo!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner - hanya ditampilkan jika banner terisi
          if (info.bannerImage != null && info.bannerImage!.trim().isNotEmpty) ...[
            _buildBannerCard(info.bannerImage!),
            const SizedBox(height: 16),
          ],

          // Kartu informasi form (judul, deskripsi, jumlah soal, timer, jam buka/tutup, token)
          _buildInfoCard(info),

          // Status info (one response, requires login)
          if (info.oneResponse || info.requiresLogin) ...[
            const SizedBox(height: 16),
            _buildStatusInfo(info),
          ],

          const SizedBox(height: 24),

          // Tombol Mulai
          AuthPrimaryButton(
            label: "Mulai Mengerjakan",
            loading: _validatingToken,
            onPressed: _validatingToken ? null : _startForm,
          ),

          const SizedBox(height: 12),
          const Text(
            "Pastikan Anda menjawab semua pertanyaan dengan benar sebelum mengirim.",
            style: TextStyle(fontSize: 12, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Kartu banner form
  Widget _buildBannerCard(String bannerImage) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          profileImageUrl(bannerImage),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            color: kPrimarySoft,
            child: const Icon(
              Icons.image_outlined,
              size: 40,
              color: kAuthPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(PublicFormInfo info) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextView(
            text: info.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            RichTextView(
              text: info.description!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],

          const Divider(height: 32),

          // Total questions
          _buildDetailRow(
            icon: Icons.quiz_outlined,
            label: "Total Pertanyaan",
            value: "${info.questionCount} soal",
          ),

          // Timer (jika ada)
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.timer_outlined,
              label: "Batas Waktu Pengerjaan",
              value: _formatDuration(info.timerDuration!),
            ),
          ],

          // Jam buka form
          if (info.openFormTime != null) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.play_circle_outline,
              label: "Form Dibuka",
              value: _formatDateTime(info.openFormTime!),
            ),
          ],

          // Jam tutup form
          if (info.closeFormTime != null) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.stop_circle_outlined,
              label: "Form Ditutup",
              value: _formatDateTime(info.closeFormTime!),
            ),
          ],

          // Input token - digabung ke dalam kartu informasi
          if (info.requiresToken) ...[
            const Divider(height: 32),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: kAuthPrimary),
                SizedBox(width: 8),
                Text(
                  "Form Ini Memerlukan Token",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: kAuthPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _tokenController,
              hint: "Masukkan token akses",
              icon: Icons.key,
            ),
            if (_tokenError != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFC0392B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _tokenError!,
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                "Token diberikan oleh pemilik form. Hubungi pemilik untuk mendapatkan token.",
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kAuthPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(PublicFormInfo info) {
    return Row(
      children: [
        if (info.oneResponse) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F4E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF2E7D32),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Hanya 1x kesempatan",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (info.oneResponse && info.requiresLogin) const SizedBox(width: 8),
        if (info.requiresLogin) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: kAuthPrimary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Harus login",
                      style: TextStyle(
                        fontSize: 12,
                        color: kAuthPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Format durasi dari detik menjadi "X jam Y menit" / "Y menit"
  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return "$h jam $m menit";
    if (h > 0) return "$h jam";
    if (m > 0) return "$m menit";
    return "$seconds detik";
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
  }
}