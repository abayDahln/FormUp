import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu langkah tur: anchor widget target (opsional — null = card tengah)
/// + penjelasan + aksi opsional saat langkah dimulai (mis. pindah tab).
/// [extraAnchorKeys] menyorot beberapa area sekaligus (mis. dua baris menu).
class OnboardingStep {
  final GlobalKey? anchorKey;
  final List<GlobalKey> extraAnchorKeys;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onEnter;

  /// Jeda (ms) setelah langkah aktif sebelum posisi dikunci — untuk anchor
  /// yang baru muncul (pindah tab / animasi FAB) agar tidak terkunci prematur.
  final int settleMs;

  /// Padding lubang spotlight khusus langkah ini.
  final double spotlightPadding;

  const OnboardingStep({
    this.anchorKey,
    this.extraAnchorKeys = const [],
    required this.title,
    required this.description,
    this.icon = Icons.lightbulb_outline,
    this.onEnter,
    this.settleMs = 150,
    this.spotlightPadding = 6,
  });
}

/// Tur panduan interaktif pola spotlight (paritas web OnboardingTour):
/// overlay gelap + cutout di target + card penjelasan + Lewati.
/// Selesai/lewati → [onComplete] (panggil sekali) agar pemanggil bisa
/// menandai flag "sudah dilihat".
class OnboardingTour extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;

  const OnboardingTour({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour> {
  int _index = 0;
  List<Rect> _targetRects = const [];
  bool _placeAbove = false;
  bool _done = false;
  int _locateTries = 0;

  @override
  void initState() {
    super.initState();
    widget.steps[_index].onEnter?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onComplete();
  }

  Rect? _boxRect(GlobalKey key, Size screen, double padding) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    final pos = box.localToGlobal(Offset.zero);
    var rect = Rect.fromLTWH(
      pos.dx - padding,
      pos.dy - padding,
      box.size.width + padding * 2,
      box.size.height + padding * 2,
    );
    // Jepit ke layar agar lubang di tepi (mis. FAB) tidak kepotong.
    rect = Rect.fromLTRB(
      rect.left.clamp(8.0, screen.width - 8),
      rect.top.clamp(8.0, screen.height - 8),
      rect.right.clamp(8.0, screen.width - 8),
      rect.bottom.clamp(8.0, screen.height - 8),
    );
    if (rect.isEmpty) return null;
    return rect;
  }

  void _locate({bool resettle = true}) {
    if (!mounted || _done) return;
    final step = widget.steps[_index];
    final screen = MediaQuery.of(context).size;
    final rects = <Rect>[];
    final keys = [
      if (step.anchorKey != null) step.anchorKey!,
      ...step.extraAnchorKeys,
    ];
    for (final key in keys) {
      final rect = _boxRect(key, screen, step.spotlightPadding);
      if (rect != null) rects.add(rect);
    }
    if (rects.isEmpty && keys.isNotEmpty && _locateTries < 8) {
      // Anchor belum ter-layout (mis. baru pindah tab) — coba lagi frame berikut.
      _locateTries++;
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
      return;
    }
    _locateTries = 0;
    if (!mounted) return;
    final union = rects.isEmpty
        ? null
        : rects.skip(1).fold<Rect>(
            rects.first, (a, b) => a.expandToInclude(b));
    setState(() {
      _targetRects = rects;
      // Card di bawah target bila muat, else di atas.
      _placeAbove = union != null &&
          screen.height - union.bottom < 300 &&
          union.top > 320;
    });
    if (resettle && rects.isNotEmpty && step.settleMs > 0) {
      // Kunci ulang posisi setelah jeda: mengejar layout yang masih
      // bergeser (animasi tab/FAB) agar lubang tidak offsite.
      final index = _index;
      Future.delayed(Duration(milliseconds: step.settleMs), () {
        if (mounted && !_done && _index == index) _locate(resettle: false);
      });
    }
  }

  void _go(int next) {
    if (next < 0 || next >= widget.steps.length) return;
    widget.steps[next].onEnter?.call();
    setState(() {
      _index = next;
      _targetRects = const [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = widget.steps[_index];
    final isLast = _index == widget.steps.length - 1;
    final size = MediaQuery.of(context).size;
    final rect = _targetRects.isEmpty
        ? null
        : _targetRects
            .skip(1)
            .fold<Rect>(_targetRects.first, (a, b) => a.expandToInclude(b));

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Overlay gelap; tap di luar card = tetap di tempat (anti salah pencet).
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: CustomPaint(
                painter: _SpotlightPainter(_targetRects),
              ),
            ),
          ),
          // Card penjelasan.
          Positioned(
            left: 20,
            right: 20,
            top: rect == null
                ? size.height * 0.35
                : (_placeAbove
                    ? (rect.top - 290).clamp(60.0, size.height - 320)
                    : (rect.bottom + 12).clamp(60.0, size.height - 320)),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Langkah ${_index + 1} dari ${widget.steps.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Skip kapan saja selama tur berjalan.
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Lewati',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(step.icon, color: cs.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Dots.
                      ...List.generate(
                        widget.steps.length,
                        (i) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? cs.primary
                                : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_index > 0)
                        TextButton(
                          onPressed: () => _go(_index - 1),
                          child: const Text('Kembali'),
                        ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kAuthPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (isLast) {
                            _finish();
                          } else {
                            _go(_index + 1);
                          }
                        },
                        child: Text(isLast ? 'Selesai' : 'Lanjut'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pelukis overlay + lubang spotlight di sekitar target + ring cahaya.
class _SpotlightPainter extends CustomPainter {
  final List<Rect> targets;
  static const _glow = Color(0xFF2DD4BF);

  _SpotlightPainter(this.targets);

  @override
  void paint(Canvas canvas, Size size) {
    // PENTING: bounds saveLayer harus seukuran kanvas — Rect.largest
    // membuat komposit clear gagal di sebagian backend.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawColor(
      Colors.black.withValues(alpha: 0.72),
      BlendMode.srcOver,
    );
    for (final target in targets) {
      final rrect = RRect.fromRectAndRadius(target, const Radius.circular(14));
      canvas.drawRRect(
        rrect,
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.restore();
    // Ring cahaya penegas di sekeliling tiap lubang (di luar layer clear).
    for (final target in targets) {
      final rrect = RRect.fromRectAndRadius(target, const Radius.circular(14));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _glow.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.targets != targets;
}

/// Sinyal global "langsung mulai tur Beranda" (dipakai menu Panduan di
/// Settings): naikkan [homeTourRequest.value], HomeScreen yang mendengar
/// akan pindah ke tab Beranda dan menampilkan tur.
final homeTourRequest = ValueNotifier<int>(0);

/// Flag "tur sudah dilihat" per-akun (pola sama seperti chat history).
class OnboardingFlags {
  static String _key(String name, String? email) {
    final id = (email ?? '').trim().toLowerCase();
    return 'onboarding_${name}_seen::$id';
  }

  static Future<bool> isSeen(String name, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(name, email)) ?? false;
  }

  static Future<void> markSeen(String name, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(name, email), true);
  }

  static Future<void> reset(String name, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(name, email));
  }
}
