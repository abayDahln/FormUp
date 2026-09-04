import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
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

  const ActionChangeCard({
    super.key,
    required this.message,
    this.onUndo,
    this.onRedo,
  });

  @override
  State<ActionChangeCard> createState() => _ActionChangeCardState();
}

class _ActionChangeCardState extends State<ActionChangeCard> {
  bool _expanded = false;

  ChatMessage get m => widget.message;

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

  (String, Color) _status() {
    if (m.actionStatus == 'rejected') return ('Ditolak', Colors.red);
    if (m.actionUndone) return ('Di-undo', Colors.black38);
    if (m.actionStatus == 'accepted' && m.actionExecuted) {
      return ('Diterima', Colors.green);
    }
    if (m.actionStatus == 'pending') return ('Menunggu', Colors.orange);
    return ('', Colors.black38);
  }

  // ---- Detail perubahan (isi dropdown) ----

  /// Judul satu item perubahan ("Soal 3", "Form: ...", "isExamMode").
  Widget _itemTitle(String text, {Color color = Colors.black87}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      );

  /// Satu baris diff berlabel ("Lama" / "Baru" / dll) — maksimal 1 baris
  /// agar kartu tetap compact.
  Widget _diffLine({
    required String label,
    required String text,
    required Color color,
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
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text.isEmpty ? '(kosong)' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );

  /// Label soal memakai NOMOR URUT (bukan id database) agar wajar dibaca user.
  String _soalLabel(int? order) => order != null ? 'Soal $order' : 'Soal';

  Widget _editItem(int? order, String? oldQ, String? newQ) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order)),
            _diffLine(label: 'Lama', text: _clean(oldQ), color: Colors.black38),
            _diffLine(label: 'Baru', text: _clean(newQ), color: kAuthPrimary),
          ],
        ),
      );

  Widget _addLine(String? question, {int? order}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order)),
            _diffLine(
              label: 'Baru',
              text: _clean(question),
              color: Colors.green,
            ),
          ],
        ),
      );

  Widget _deleteItem(int? order, String? question) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _itemTitle(_soalLabel(order), color: Colors.red),
            Text(
              _clean(question).isEmpty ? '(kosong)' : _clean(question),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.black26,
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

  List<Widget> _detailItems() {
    final a = m.actionJson!;
    final undo = m.undoSnapshot;
    switch (a['action']) {
      case 'create_form':
        final title = _clean(a['title'] as String?);
        return [
          _itemTitle('Form: ${title.isEmpty ? '(tanpa judul)' : title}'),
          for (final q in (a['questions'] as List<dynamic>? ?? []))
            _addLine(
              (q as Map)['question'] as String?,
              order: _orderOf(q),
            ),
        ];
      case 'add_questions':
        return [
          for (final q in (a['questions'] as List<dynamic>? ?? []))
            _addLine(
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
                _orderOf(o as Map),
                o['question'] as String?,
              ),
          ];
        }
        return [
          for (final _ in (a['questionIds'] as List<dynamic>? ?? []))
            _itemTitle('Soal', color: Colors.red),
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
                  _itemTitle('$k'),
                  _diffLine(label: 'Lama', text: '$p', color: Colors.black38),
                  _diffLine(label: 'Baru', text: '$n', color: kAuthPrimary),
                ],
              ),
            ));
          }
        }
        if (items.isEmpty) {
          items.add(const Text(
            'Pengaturan form diperbarui',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ));
        }
        return items;
      default:
        return const [];
    }
  }

  /// Detail + divider antar item agar blok per soal terpisah jelas.
  List<Widget> _detailWidgets() {
    final items = _detailItems();
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(const Divider(
          height: 10,
          thickness: 0.7,
          color: Color(0xFFE3ECEB),
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status();
    final detailWidgets = _detailWidgets();
    final canUndo = m.actionStatus == 'accepted' &&
        m.actionExecuted &&
        !m.actionUndone &&
        widget.onUndo != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDC9C8)),
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
                          : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _summary(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  if (canUndo)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onUndo,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, size: 13, color: Colors.black54),
                            SizedBox(width: 3),
                            Text(
                              'Undo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (m.actionUndone && widget.onRedo != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onRedo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.redo,
                                size: 13, color: kAuthPrimary),
                            const SizedBox(width: 3),
                            Text(
                              'Redo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kAuthPrimary,
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
                      'Menunggu persetujuan — gunakan tombol Terima/Tolak di atas',
                      style: TextStyle(fontSize: 10.5, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          // Aksi sudah dijalankan & form diketahui: langsung ke detail form.
          if (m.actionExecuted && m.actionFormId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAuthPrimary,
                    backgroundColor: kPrimarySoft,
                    side: const BorderSide(color: kAuthPrimary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => AppRouter.of(context).push(
                    AppPage.formDetail,
                    {'formId': m.actionFormId},
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text(
                    'Buka Form',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
