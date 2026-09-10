import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/services/exam_warning_sound.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';

/// Kartu pengaturan form maker: tipe, link kustom, timer, token,
/// waktu buka/tutup, dan switch-switch opsi
class FormMakerSettingsCard extends StatelessWidget {
  final FormMakerController controller;
  final VoidCallback onChanged;
  final VoidCallback onPickOpenTime;
  final VoidCallback onPickCloseTime;
  final bool embedded;

  const FormMakerSettingsCard({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onPickOpenTime,
    required this.onPickCloseTime,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = controller;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded) ...[
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
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
                  // Tipe "Ujian" otomatis mengaktifkan Mode Ujian;
                  // "Formulir" selalu non-ujian (tanpa pilihan manual).
                  c.isExamMode = (v == 2);
                  if (v == 2) {
                    // Default ujian: semua pengaman aktif + batas 1x.
                    c.disableCopyPaste = true;
                    c.detectTabSwitch = true;
                    c.autoSubmitOnTabSwitch = true;
                    c.maxTabSwitch ??= 1;
                  } else {
                    c.disableCopyPaste = false;
                    c.detectTabSwitch = false;
                    c.autoSubmitOnTabSwitch = false;
                  }
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
          decoration: _fieldDecoration("Kode untuk link form Anda"),
          onChanged: (v) => c.customLinkController.value = c
              .customLinkController
              .value
              .copyWith(
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
                decoration: _fieldDecoration("Batas waktu pengerjaan"),
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
          decoration: _fieldDecoration("Token untuk akses form"),
        ),
        const SizedBox(height: 8),
        _settingsLabel("Waktu buka form"),
        _DateTimeTile(
          hint: "Pilih waktu buka",
          value: c.openFormTime,
          onTap: onPickOpenTime,
        ),
        const SizedBox(height: 8),
        _settingsLabel("Waktu tutup form"),
        _DateTimeTile(
          hint: "Pilih waktu tutup",
          value: c.closeFormTime,
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
        const Divider(height: 24),
        if (c.formTypeId == 2) ...[
          _settingsLabel("Pengaturan Ujian"),
          _SettingSwitch(
            "Cegah salin-tempel",
            "Nonaktifkan copy-paste saat mengerjakan",
            c.disableCopyPaste,
            (v) {
              c.disableCopyPaste = v;
              onChanged();
            },
          ),
          _SettingSwitch(
            "Deteksi pindah tab",
            "Peringatan saat keluar aplikasi",
            c.detectTabSwitch,
            (v) {
              c.detectTabSwitch = v;
              onChanged();
            },
          ),
          _SettingSwitch(
            "Auto submit saat pindah",
            "Otomatis kumpulkan saat deteksi keluar",
            c.autoSubmitOnTabSwitch,
            (v) {
              c.autoSubmitOnTabSwitch = v;
              onChanged();
            },
          ),
          const SizedBox(height: 6),
          _settingsLabel("Batas pindah tab (0=tanpa batas)"),
          TextField(
            controller: TextEditingController(text: c.maxTabSwitch?.toString() ?? ''),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration("Misal: 3"),
            onChanged: (v) {
              c.maxTabSwitch = int.tryParse(v);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final err = await ExamWarningSound.testPlay();
              if (!context.mounted) return;
              showAuthToast(
                context,
                err == null
                    ? 'Bunyi peringatan diputar'
                    : 'Bunyi gagal: $err',
                isError: err != null,
              );
            },
            icon: const Icon(Icons.volume_up_outlined, size: 18),
            label: const Text('Tes bunyi peringatan',
                style: TextStyle(fontSize: 12)),
          ),
        ],
        const Divider(height: 24),
        _settingsLabel("Tema Per-Form"),
        _ThemeColorSetting(
          label: "Warna primer",
          value: c.themePrimaryColor,
          defaultHex: "#2A9D8F",
          onChanged: (v) {
            c.themePrimaryColor = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        _ThemeColorSetting(
          label: "Warna background",
          value: c.themeBackgroundColor,
          defaultHex: "#E1F9F4",
          onChanged: (v) {
            c.themeBackgroundColor = v;
            onChanged();
          },
        ),
      ],
    );

    if (embedded) return content;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: content,
    );
  }
}

Widget _settingsLabel(String text) {
  return Builder(builder: (context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  });
}

/// Switch setting dengan judul + subtitle
class _SettingSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch(this.title, this.subtitle, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Material transparan agar ink splash ListTile tidak tertutup DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(fontSize: 13, color: cs.onSurface),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        value: value,
        activeTrackColor: cs.primary,
        onChanged: onChanged,
      ),
    );
  }
}

/// Tile pemilih tanggal & waktu — selalu aktif (waktu buka bisa diubah kapan saja)
class _DateTimeTile extends StatelessWidget {
  final String hint;
  final DateTime? value;
  final VoidCallback? onTap;

  const _DateTimeTile({
    required this.hint,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? hint : _formatDateTime(value!),
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
}

/// Bungkus dropdown agar tampil seperti field text lainnya di screen ini.
Widget _dropdownCard(Widget child) {
  return Builder(builder: (context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: child,
    );
  });
}

InputDecoration _fieldDecoration(String hint) =>
    formUpInputDecoration(hintText: hint);

/// Parse "#RGB" / "#RRGGBB" ( boleh tanpa '#') → Color, null bila invalid.
Color? _parseHexColor(String raw) {
  var s = raw.trim().replaceAll('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}

String _toHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

const _presetColors = [
  "#2A9D8F", "#018081", "#2E7D32", "#1565C0", "#3949AB", "#6A1B9A",
  "#C2185B", "#C0392B", "#E65100", "#B26A00", "#5D4037", "#607D8B",
];

/// Pengaturan satu warna tema: preview + field hex + preset + slider RGB.
/// Nilai null = pakai default aplikasi.
class _ThemeColorSetting extends StatefulWidget {
  final String label;
  final String? value;
  final String defaultHex;
  final ValueChanged<String?> onChanged;

  const _ThemeColorSetting({
    required this.label,
    required this.value,
    required this.defaultHex,
    required this.onChanged,
  });

  @override
  State<_ThemeColorSetting> createState() => _ThemeColorSettingState();
}

class _ThemeColorSettingState extends State<_ThemeColorSetting> {
  late final TextEditingController _hexCtrl;
  bool _expanded = false;

  Color get _current =>
      _parseHexColor(widget.value ?? '') ??
      _parseHexColor(widget.defaultHex) ??
      const Color(0xFF2A9D8F);

  @override
  void initState() {
    super.initState();
    _hexCtrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(_ThemeColorSetting old) {
    super.didUpdateWidget(old);
    final v = widget.value ?? '';
    if (v.toUpperCase() != _hexCtrl.text.toUpperCase()) {
      _hexCtrl.text = v;
    }
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _apply(Color c) => widget.onChanged(_toHex(c));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _hexCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration("#RRGGBB"),
                onChanged: (v) {
                  final c = _parseHexColor(v);
                  if (c != null) widget.onChanged(_toHex(c));
                },
              ),
            ),
            IconButton(
              tooltip: "Kembali ke default",
              icon: const Icon(Icons.restart_alt, size: 20),
              color: cs.onSurfaceVariant,
              onPressed: () {
                _hexCtrl.text = '';
                widget.onChanged(null);
              },
            ),
            IconButton(
              tooltip: _expanded ? "Tutup" : "Pilih warna",
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.palette_outlined,
                size: 20,
              ),
              color: cs.primary,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in _presetColors)
                Builder(builder: (_) {
                  final c = _parseHexColor(hex)!;
                  final selected =
                      _toHex(current) == _toHex(c);
                  return InkWell(
                    onTap: () {
                      _hexCtrl.text = _toHex(c);
                      _apply(c);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? cs.primary : cs.outlineVariant,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 4),
          for (final ch in ['R', 'G', 'B'])
            Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text(ch,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant)),
                ),
                Expanded(
                  child: Slider(
                    value: (ch == 'R'
                            ? current.r
                            : ch == 'G'
                                ? current.g
                                : current.b) *
                        255,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    activeColor: cs.primary,
                    label:
                        '${((ch == 'R' ? current.r : ch == 'G' ? current.g : current.b) * 255).round()}',
                    onChanged: (v) {
                      final r = ch == 'R'
                          ? (v / 255)
                          : current.r.toDouble();
                      final g = ch == 'G'
                          ? (v / 255)
                          : current.g.toDouble();
                      final b = ch == 'B'
                          ? (v / 255)
                          : current.b.toDouble();
                      final c = Color.from(
                        alpha: 1,
                        red: r,
                        green: g,
                        blue: b,
                      );
                      _hexCtrl.text = _toHex(c);
                      _apply(c);
                    },
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${((ch == 'R' ? current.r : ch == 'G' ? current.g : current.b) * 255).round()}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
