import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';

/// Kartu pengaturan form maker: tipe, link kustom, timer, token,
/// waktu buka/tutup, dan switch-switch opsi
class FormMakerSettingsCard extends StatelessWidget {
  final FormMakerController controller;
  final VoidCallback onChanged;
  final VoidCallback onPickOpenTime;
  final VoidCallback onPickCloseTime;

  const FormMakerSettingsCard({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onPickOpenTime,
    required this.onPickCloseTime,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: kAuthPrimary),
              const SizedBox(width: 8),
              const Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _settingsLabel("Tipe Form"),
          _dropdownCard(
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: c.formTypeId,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Formulir")),
                  DropdownMenuItem(value: 2, child: Text("Ujian")),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.formTypeId = v;
                    onChanged();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _settingsLabel("Kode Link Kustom"),
          TextField(
            controller: c.customLinkController,
            decoration: _fieldDecoration(
              "Kode untuk link form Anda",
            ),
            onChanged: (v) => c.customLinkController.value =
                c.customLinkController.value.copyWith(
              text: sanitizeFormLink(v),
              selection: TextSelection.collapsed(
                offset: sanitizeFormLink(v).length,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _settingsLabel("Waktu Mengerjakan"),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c.timerController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDecoration(
                    "Batas waktu pengerjaan",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _dropdownCard(
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: c.timerUnit,
                    items: const [
                      DropdownMenuItem(value: 'menit', child: Text("Menit")),
                      DropdownMenuItem(value: 'jam', child: Text("Jam")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        c.timerUnit = v;
                        onChanged();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _settingsLabel("Token Akses"),
          TextField(
            controller: c.tokenController,
            decoration: _fieldDecoration(
              "Token untuk akses form",
            ),
          ),
          const SizedBox(height: 8),
          _DateTimeTile(
            icon: Icons.lock_open_outlined,
            title: "Waktu buka form",
            subtitle: c.openTimeAlreadySet
                ? "Sudah diatur, tidak bisa diubah"
                : "Form terbuka otomatis di waktu ini",
            value: c.openFormTime,
            enabled: !c.openTimeAlreadySet,
            onTap: c.openTimeAlreadySet ? null : onPickOpenTime,
          ),
          const SizedBox(height: 8),
          _DateTimeTile(
            icon: Icons.lock_outline,
            title: "Waktu tutup form",
            subtitle: "Form berhenti menerima respons",
            value: c.closeFormTime,
            enabled: true,
            onTap: onPickCloseTime,
          ),
          const SizedBox(height: 8),
          _SettingSwitch(
            "Tampilkan skor",
            "Responden melihat nilai setelah submit",
            c.showScore,
            (v) {
              c.showScore = v;
              onChanged();
            },
          ),
          _SettingSwitch(
            "Acak pertanyaan",
            "Urutan pertanyaan diacak",
            c.randomizeQuestions,
            (v) {
              c.randomizeQuestions = v;
              onChanged();
            },
          ),
          _SettingSwitch(
            "Satu respons per orang",
            "Batasi tiap orang hanya 1 kali isi",
            c.oneResponse,
            (v) {
              c.oneResponse = v;
              onChanged();
            },
          ),
          _SettingSwitch(
            "Wajib login",
            "Responden harus login untuk mengerjakan",
            c.requiredLogin,
            (v) {
              c.requiredLogin = v;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

Widget _settingsLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: kAuthPrimary,
      ),
    ),
  );
}

/// Switch setting dengan judul + subtitle
class _SettingSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch(
    this.title,
    this.subtitle,
    this.value,
    this.onChanged,
  );

  @override
  Widget build(BuildContext context) {
    // Material transparan agar ink splash ListTile tidak tertutup DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        value: value,
        activeTrackColor: kAuthPrimary,
        onChanged: onChanged,
      ),
    );
  }
}

/// Tile pemilih tanggal & waktu
class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? value;
  final bool enabled;
  final VoidCallback? onTap;

  const _DateTimeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? const Color(0xFF6E7979) : const Color(0xFFD8DEDE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? kAuthPrimary : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null
                        ? (enabled ? subtitle : "Belum diatur")
                        : _formatDateTime(value!),
                    style: TextStyle(
                      fontSize: 12,
                      color: value != null
                          ? kAuthPrimary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey)
            else
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
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

/// Bungkus dropdown agar tampil seperti field text lainnya di screen ini.
Widget _dropdownCard(Widget child) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF6E7979)),
    ),
    child: child,
  );
}

InputDecoration _fieldDecoration(String hint) => formUpInputDecoration(hintText: hint);
