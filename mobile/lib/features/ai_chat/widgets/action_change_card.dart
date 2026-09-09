import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/features/ai_chat/models/chat_message.dart';

/// Kartu ringkasan perubahan (gaya diff) di bawah bubble AI yang berisi
/// aksi form/soal:
/// - Baris ringkasan: "Ubah soal • 3 soal diubah" + chip status + tombol Undo.
/// - Tap baris → dropdown detail perubahan: tiap soal ditampilkan sebagai
///   blok "Lama → Baru" yang mudah dibaca (bukan satu baris kecil).
/// - Tombol "Buka Form" saat aksi sudah dijalankan.
/// Muncul untuk SEMUA status aksi (menunggu / diterima / ditolak / di-undo).
class ActionChangeCard extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onUndo;

  /// Terapkan kembali perubahan yang sudah di-undo (null = sembunyikan).
  final VoidCallback? onRedo;

  /// False saat AI sedang mengetik: tombol Undo/Redo dinonaktifkan.
  final bool disabled;

  const ActionChangeCard({
    super.key,
    required this.message,
    this.onUndo,
    this.onRedo,
    this.disabled = false,
  });

  @override
  State<ActionChangeCard> createState() => _ActionChangeCardState();
}

class _ActionChangeCardState extends State<ActionChangeCard> {
  bool _expanded = false;
  bool _opening = false;

  ChatMessage get m => widget.message;

  /// Buka form dengan validasi dulu: preload data form agar layar tujuan
  /// tidak terbuka kosong/error (mis. formId basi atau form sudah dihapus).
  Future<void> _openForm() async {
    final formId = m.actionFormId;
    if (formId == null || _opening) return;
    setState(() => _opening = true);
    try {
      final data = await FormService.getForm(formId);
      if (!mounted) return;
      AppRouter.of(context).push(AppPage.formDetail, {
        'formId': formId,
        'form': FormData.fromJson(data),
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context,
          'Form tidak bisa dibuka: ${AuthService.errorMessage(e)}',
          isError: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Langsung ke kelola soal (tempat user biasa memulai edit via AI).
  void _openQuestions() {
    final formId = m.actionFormId;
    if (formId == null) return;
    AppRouter.of(context).push(AppPage.formQuestions, {'formId': formId});
  }

  /// True bila aksi menyentuh daftar soal (pantas ada tombol Kelola Soal).
  bool get _touchesQuestions {
    final act = m.actionJson?['action'] as String?;
    return act == 'edit_questions' ||
        act == 'add_questions' ||
        act == 'delete_questions' ||
        act == 'create_form';
  }

  String _clean(String? s) => (s ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ---- Ringkasan (baris kepala kartu) ----

  String _summary() {
    final a = m.actionJson!;
    switch (a['action']) {
      case 'create_form':
        final n = (a['questions'] as List<dynamic>?)?.length ?? 0;
        return 'Form baru • ${n > 0 ? '$n soal' : 'tanpa soal'}';
      case 'add_questions':
        final n = (a['questions'] as List<dynamic>?)?.length ?? 0;
        return 'Tambah soal • $n soal baru';
      case 'edit_questions':
        final n = (a['questions'] as List<dynamic>?)?.length ?? 0;
        return 'Ubah soal • $n soal diubah';
      case 'delete_questions':
        final n = (a['questionIds'] as List<dynamic>?)?.length ?? 0;
        return 'Hapus soal • $n soal dihapus';
      case 'update_settings':
        return 'Ubah pengaturan form';
      default:
        return 'Aksi: ${a['action']}';
    }
  }

  (String, Color) _status(ColorScheme cs) {
    if (m.actionStatus == 'rejected') return ('Ditolak', Colors.red);
    if (m.actionUndone) return ('Di-undo', cs.onSurfaceVariant);
    if (m.actionStatus == 'accepted' && m.actionExecuted) {
      return ('Diterima', Colors.green);
    }
    if (m.actionStatus == 'pending') return ('Menunggu', Colors.orange);
    return ('', cs.onSurfaceVariant);
  }

  // ---- Detail perubahan (isi dropdown) ----

  /// Judul satu item perubahan ("Soal 3", "Form: ...", "isExamMode").
  Widget _itemTitle(String text, ColorScheme cs, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700, fontFamily: kFontBold,
              color: color ?? cs.onSurface),
        ),
      );

  /// Satu baris diff berlabel ("Lama" / "Baru" / dll) — maksimal 1 baris
  /// agar kartu tetap compact.
  Widget _diffLine({
    required String label,
    required String text,
    required Color color,
    required ColorScheme cs,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: kFontBold, color: color),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text.isEmpty ? '(kosong)' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      );

  /// Label soal memakai NOMOR URUT (bukan id database) agar wajar dibaca user.
  String _soalLabel(int? order) => order != null ? 'Soal $order' : 'Soal';

  Widget _editItem(ColorScheme cs, int? order, String? oldQ, String? newQ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order), cs),
            _diffLine(
                label: 'Lama',
                text: _clean(oldQ),
                color: cs.onSurfaceVariant,
                cs: cs),
            _diffLine(
                label: 'Baru',
                text: _clean(newQ),
                color: cs.primary,
                cs: cs),
          ],
        ),
      );

  Widget _addLine(ColorScheme cs, String? question, {int? order}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order), cs),
            _diffLine(
              label: 'Baru',
              text: _clean(question),
              color: Colors.green,
              cs: cs,
            ),
          ],
        ),
      );

  Widget _deleteItem(ColorScheme cs, int? order, String? question) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order), cs, color: Colors.red),
            Text(
              _clean(question).isEmpty ? '(kosong)' : _clean(question),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: cs.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                decorationColor: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  /// Ambil nomor urut soal dari data snapshot (paling akurat) atau dari
  /// aksi AI sebagai cadangan.
  int? _orderOf(Map item) {
    final qo = item['questionOrder'] ?? item['order'];
    return qo is int ? qo : int.tryParse('$qo');
  }

  List<Widget> _detailItems(ColorScheme cs) {
    final a = m.actionJson!;
    final undo = m.undoSnapshot;
    switch (a['action']) {
      case 'create_form':
        final title = _clean(a['title'] as String?);
        return [
          _itemTitle('Form: ${title.isEmpty ? '(tanpa judul)' : title}', cs),
          for (final q in (a['questions'] as List<dynamic>? ?? []))
            _addLine(
              cs,
              (q as Map)['question'] as String?,
              order: _orderOf(q),
            ),
        ];
      case 'add_questions':
        return [
          for (final q in (a['questions'] as List<dynamic>? ?? []))
            _addLine(
              cs,
              (q as Map)['question'] as String?,
              order: _orderOf(q),
            ),
        ];
      case 'edit_questions':
        final olds = {
          for (final o in (undo?['originalQuestions'] as List<dynamic>? ?? []))
            (o as Map)['id']: o,
        };
        return [
          for (final q in (a['questions'] as List<dynamic>? ?? []))
            () {
              final map = q as Map;
              final orig = olds[map['id']];
              return _editItem(
                cs,
                orig != null ? _orderOf(orig) : _orderOf(map),
                orig?['question'] as String?,
                map['question'] as String?,
              );
            }(),
        ];
      case 'delete_questions':
        final deleted = undo?['deletedQuestions'] as List<dynamic>?;
        if (deleted != null && deleted.isNotEmpty) {
          return [
            for (final o in deleted)
              _deleteItem(
                cs,
                _orderOf(o as Map),
                o['question'] as String?,
              ),
          ];
        }
        return [
          for (final _ in (a['questionIds'] as List<dynamic>? ?? []))
            _itemTitle('Soal', cs, color: Colors.red),
        ];
      case 'update_settings':
        final prev = (undo?['previousSettings'] as Map<dynamic, dynamic>?) ?? {};
        final next = (a['settings'] as Map<dynamic, dynamic>?) ?? {};
        final items = <Widget>[];
        for (final k in {...prev.keys, ...next.keys}) {
          final p = prev[k];
          final n = next[k];
          if ('$p' != '$n') {
            items.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _itemTitle('$k', cs),
                  _diffLine(
                      label: 'Lama',
                      text: '$p',
                      color: cs.onSurfaceVariant,
                      cs: cs),
                  _diffLine(
                      label: 'Baru', text: '$n', color: cs.primary, cs: cs),
                ],
              ),
            ));
          }
        }
        if (items.isEmpty) {
          items.add(Text(
            'Pengaturan form diperbarui',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ));
        }
        return items;
      default:
        return const [];
    }
  }

  /// Detail + divider antar item agar blok per soal terpisah jelas.
  List<Widget> _detailWidgets(ColorScheme cs) {
    final items = _detailItems(cs);
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(Divider(
          height: 10,
          thickness: 0.7,
          color: cs.outlineVariant,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = _status(cs);
    final detailWidgets = _detailWidgets(cs);
    final canUndo = m.actionStatus == 'accepted' &&
        m.actionExecuted &&
        !m.actionUndone &&
        widget.onUndo != null &&
        !widget.disabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris kepala: chevron + ringkasan + status + Undo.
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: detailWidgets.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: detailWidgets.isEmpty
                          ? Colors.transparent
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _summary(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold, fontFamily: kFontBold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (statusLabel.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700, fontFamily: kFontBold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  if (canUndo)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onUndo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              'Undo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600, fontFamily: kFontBold,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (m.actionUndone &&
                      widget.onRedo != null &&
                      !widget.disabled)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onRedo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.redo,
                                size: 13, color: cs.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Redo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700, fontFamily: kFontBold,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Dropdown detail perubahan.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: detailWidgets,
              ),
            ),
          ),
          // Petunjuk untuk aksi yang masih pending.
          if (m.actionStatus == 'pending')
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top,
                      size: 12, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Menunggu persetujuan. Gunakan tombol Terima atau Tolak di atas',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          // Aksi sudah dijalankan & form diketahui: validasi dulu lalu buka.
          if (m.actionExecuted && m.actionFormId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        backgroundColor: cs.primaryContainer,
                        side: BorderSide(color: cs.primary, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _opening ? null : _openForm,
                      icon: _opening
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.open_in_new, size: 14),
                      label: const Text(
                        'Buka Form',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: kFontBold),
                      ),
                    ),
                  ),
                  if (_touchesQuestions) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _openQuestions,
                        icon: const Icon(Icons.quiz_outlined, size: 14),
                        label: const Text(
                          'Kelola Soal',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: kFontBold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
