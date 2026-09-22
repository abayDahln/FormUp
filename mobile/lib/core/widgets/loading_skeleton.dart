import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart'
    show kRadius, softShadow;
import 'package:form_up/core/widgets/responsive.dart'
    show ResponsiveGrid, isExpanded;

/// Shimmer halus tanpa dependensi tambahan — kilau putih berjalan di atas
/// placeholder abu agar loading terlihat hidup, bukan spinner/full-blank.
class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(
        min: -1.0,
        max: 2.0,
        period: const Duration(milliseconds: 1500),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _stop(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final t = _controller.value;
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            stops: [_stop(t - 0.25), _stop(t), _stop(t + 0.25)],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Satu balok placeholder abu (otomatis ikut tema terang/gelap).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Lingkaran placeholder (avatar/icon).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Kotak ikon placeholder (seperti ikon 22px ber-padding 11 di kartu asli).
class SkeletonIconBox extends StatelessWidget {
  final double size;
  final double borderRadius;

  const SkeletonIconBox({super.key, this.size = 44, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton satu baris aktivitas (avatar + 2 baris teks).
class SkeletonListTile extends StatelessWidget {
  final bool showAvatar;

  const SkeletonListTile({super.key, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar) ...[
            const SkeletonCircle(size: 34),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirror [HomeRecentActivity._ActivityItem]: padding 12, lingkaran ikon 34,
/// baris judul (13px) + jam (11px), baris kode (12px).
class SkeletonActivityRow extends StatelessWidget {
  final bool showDivider;

  const SkeletonActivityRow({super.key, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonCircle(size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonBox(height: 14, borderRadius: 7),
                        ),
                        SizedBox(width: 8),
                        SkeletonBox(width: 52, height: 11, borderRadius: 6),
                      ],
                    ),
                    SizedBox(height: 5),
                    SkeletonBox(width: 110, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

/// Mirror [FormCard]: Card surface radius 20, padding 16, kotak ikon 44,
/// judul (15px), tanggal (12px), baris chip status + jumlah respons.
class SkeletonFormCard extends StatelessWidget {
  const SkeletonFormCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Row(
        children: [
          const SkeletonIconBox(size: 44, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 16, borderRadius: 8),
                const SizedBox(height: 3),
                const SkeletonBox(width: 130, height: 12, borderRadius: 6),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SkeletonBox(
                      width: 64,
                      height: 20,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 8),
                    const SkeletonBox(width: 84, height: 12, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirror [ResponseHistoryTile]: padding 16, ikon 44, judul + kode,
/// baris bawah waktu + badge "Nx dikerjakan", divider opsional.
class SkeletonHistoryTile extends StatelessWidget {
  final bool showDivider;

  const SkeletonHistoryTile({super.key, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonIconBox(size: 44, borderRadius: 12),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 16, borderRadius: 8),
                        SizedBox(height: 3),
                        SkeletonBox(width: 140, height: 13, borderRadius: 6),
                      ],
                    ),
                  ),
                  const SkeletonBox(
                    width: 20,
                    height: 20,
                    borderRadius: 6,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  SkeletonBox(width: 90, height: 12, borderRadius: 6),
                  Spacer(),
                  SkeletonBox(width: 96, height: 22, borderRadius: 6),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

/// Mirror [ResponseAnalyticsTile]: padding 16, ikon 44, judul + jumlah,
/// label "Responden" + chevron, divider opsional.
class SkeletonAnalyticsTile extends StatelessWidget {
  final bool showDivider;

  const SkeletonAnalyticsTile({super.key, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SkeletonIconBox(size: 44, borderRadius: 12),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16, borderRadius: 8),
                    SizedBox(height: 3),
                    SkeletonBox(width: 100, height: 13, borderRadius: 6),
                  ],
                ),
              ),
              const SkeletonBox(width: 64, height: 15, borderRadius: 7),
              const SizedBox(width: 4),
              const SkeletonBox(width: 20, height: 20, borderRadius: 6),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

/// Kontainer grup (mirror wadah tile riwayat/responden di tab Respon):
/// surface radius 20 + shadow, berisi tile-tile + divider.
class SkeletonGroupedList extends StatelessWidget {
  final int itemCount;
  final bool historyStyle;

  const SkeletonGroupedList.history({super.key, this.itemCount = 3})
      : historyStyle = true;

  const SkeletonGroupedList.analytics({super.key, this.itemCount = 3})
      : historyStyle = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: softShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++)
              if (historyStyle)
                SkeletonHistoryTile(showDivider: i != itemCount - 1)
              else
                SkeletonAnalyticsTile(showDivider: i != itemCount - 1),
          ],
        ),
      ),
    );
  }
}

/// Mirror [ResponseListCard] (keadaan collapsed): surface radius 16 + shadow,
/// lingkaran nomor 34, nama (14px), waktu (11px), chevron.
class SkeletonResponseCard extends StatelessWidget {
  const SkeletonResponseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SkeletonCircle(size: 34),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 15, borderRadius: 7),
                SizedBox(height: 4),
                SkeletonBox(width: 130, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SkeletonBox(width: 20, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror [AnalyticsRespondentCard]: surface radius 16, padding 16,
/// avatar 34, nama (14px) + info (11px), chip skor, chevron.
class SkeletonRespondentCard extends StatelessWidget {
  const SkeletonRespondentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SkeletonCircle(size: 34),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 15, borderRadius: 7),
                SizedBox(height: 3),
                SkeletonBox(width: 170, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SkeletonBox(width: 56, height: 26, borderRadius: 8),
          const SizedBox(width: 4),
          const SkeletonBox(width: 20, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror kartu admin (_AdminCard): surface radius 20, padding 16,
/// kotak ikon 44, judul (15px) + 2 baris sub (12px) + 2 badge, chevron.
class SkeletonAdminCard extends StatelessWidget {
  const SkeletonAdminCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonIconBox(size: 44, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 16, borderRadius: 8),
                const SizedBox(height: 4),
                const SkeletonBox(height: 12, borderRadius: 6),
                const SizedBox(height: 4),
                const SkeletonBox(width: 200, height: 12, borderRadius: 6),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SkeletonBox(width: 64, height: 18, borderRadius: 6),
                    const SizedBox(width: 6),
                    const SkeletonBox(width: 52, height: 18, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 20, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror kartu umpan balik: surface radius 12 + border, padding 16,
/// baris nama (14px) + waktu (11px), chip alasan, 2 baris deskripsi.
class SkeletonFeedbackCard extends StatelessWidget {
  const SkeletonFeedbackCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 15, borderRadius: 7)),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 11, borderRadius: 6),
            ],
          ),
          SizedBox(height: 8),
          SkeletonBox(width: 110, height: 22, borderRadius: 6),
          SizedBox(height: 8),
          SkeletonBox(height: 12, borderRadius: 6),
          SizedBox(height: 4),
          SkeletonBox(width: 220, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror kartu attempt riwayat (_AttemptCard): surface radius 14,
/// padding 16/14, kotak nomor, judul (13px) + tanggal (12px),
/// chip skor, chevron.
class SkeletonAttemptCard extends StatelessWidget {
  const SkeletonAttemptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const SkeletonBox(width: 50, height: 36, borderRadius: 10),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, borderRadius: 7),
                SizedBox(height: 4),
                SkeletonBox(width: 110, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SkeletonBox(width: 64, height: 28, borderRadius: 8),
          const SizedBox(width: 4),
          const SkeletonBox(width: 20, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror [QuestionListCard]: surface radius 16 + border, padding 16,
/// lingkaran nomor 28, teks soal (13px, 2 baris) + label tipe (11px),
/// ikon menu.
class SkeletonQuestionCard extends StatelessWidget {
  const SkeletonQuestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 28),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, borderRadius: 7),
                SizedBox(height: 4),
                SkeletonBox(width: 180, height: 13, borderRadius: 6),
                SizedBox(height: 4),
                SkeletonBox(width: 80, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 20, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror kartu sesi monitoring: Card radius 16 + border, padding 14,
/// avatar 36 + dot, nama (14px) + info (12px), chip status, progress bar.
class SkeletonSessionCard extends StatelessWidget {
  const SkeletonSessionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 15, borderRadius: 7),
                    SizedBox(height: 3),
                    SkeletonBox(width: 140, height: 12, borderRadius: 6),
                  ],
                ),
              ),
              const SkeletonBox(width: 64, height: 22, borderRadius: 11),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox(borderRadius: 3, height: 6),
        ],
      ),
    );
  }
}

/// Mirror kartu judul (header daftar responden): surface radius 16 + shadow,
/// padding 16, judul (18px) 2 baris.
class SkeletonTitleCard extends StatelessWidget {
  const SkeletonTitleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 20, borderRadius: 8),
          SizedBox(height: 6),
          SkeletonBox(width: 200, height: 16, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Mirror satu kartu statistik ringkasan analisis: surface radius 20,
/// ikon 18, angka (18px), label (10px).
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: const Column(
        children: [
          SkeletonCircle(size: 18),
          SizedBox(height: 6),
          SkeletonBox(width: 40, height: 20, borderRadius: 8),
          SizedBox(height: 2),
          SkeletonBox(width: 56, height: 11, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Mirror [AnalyticsSummaryRow]: 3 kartu statistik sebaris.
class SkeletonSummaryRow extends StatelessWidget {
  const SkeletonSummaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: SkeletonStatCard()),
        SizedBox(width: 10),
        Expanded(child: SkeletonStatCard()),
        SizedBox(width: 10),
        Expanded(child: SkeletonStatCard()),
      ],
    );
  }
}

/// Mirror sel ringkasan tab Analisis (label kapital 11px + angka 24px).
class _SummaryCellSkeleton extends StatelessWidget {
  const _SummaryCellSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 70, height: 11, borderRadius: 6),
          SizedBox(height: 4),
          SkeletonBox(width: 48, height: 26, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Mirror strip ringkasan tab Analisis: Card padding 16 berisi 4 sel
/// (sebaris di layar lebar, 2x2 di phone — mengikuti layout asli).
class SkeletonSummaryStrip extends StatelessWidget {
  const SkeletonSummaryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final divider = Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: cs.outlineVariant,
    );
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isExpanded(context)
            ? Row(
                children: [
                  const _SummaryCellSkeleton(),
                  divider,
                  const _SummaryCellSkeleton(),
                  divider,
                  const _SummaryCellSkeleton(),
                  divider,
                  const _SummaryCellSkeleton(),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      const _SummaryCellSkeleton(),
                      divider,
                      const _SummaryCellSkeleton(),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const _SummaryCellSkeleton(),
                      divider,
                      const _SummaryCellSkeleton(),
                    ],
                  ),
                ],
              ),
      ),
    );
    return card;
  }
}

/// Mirror kartu diagram tab Analisis (nilai A–E / kelulusan / akurasi /
/// peringkat): Card padding 16 berisi judul + baris-baris batang persen.
class SkeletonChartCard extends StatelessWidget {
  final int bars;

  const SkeletonChartCard({super.key, this.bars = 5});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 16, borderRadius: 8),
            const SizedBox(height: 12),
            for (var i = 0; i < bars; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              const Row(
                children: [
                  SkeletonBox(width: 20, height: 13, borderRadius: 6),
                  SizedBox(width: 8),
                  Expanded(
                    child: SkeletonBox(height: 8, borderRadius: 4),
                  ),
                  SizedBox(width: 8),
                  SkeletonBox(width: 30, height: 13, borderRadius: 6),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mirror kartu info form di riwayat: banner 3:1, judul (18px),
/// deskripsi 2 baris, 3 baris info berikon.
class SkeletonInfoCard extends StatelessWidget {
  const SkeletonInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3,
            child: Container(color: cs.surfaceContainerHighest),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 20, borderRadius: 8),
                const SizedBox(height: 8),
                const SkeletonBox(height: 13, borderRadius: 6),
                const SizedBox(height: 6),
                const SkeletonBox(width: 250, height: 13, borderRadius: 6),
                const SizedBox(height: 14),
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  const Row(
                    children: [
                      SkeletonBox(width: 16, height: 16, borderRadius: 6),
                      SizedBox(width: 8),
                      SkeletonBox(width: 130, height: 13, borderRadius: 6),
                    ],
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

/// Mirror kartu pratinjau soal: surface radius 16 + shadow, padding 16,
/// lingkaran nomor 26 + judul (14px), area jawaban.
class SkeletonPreviewCard extends StatelessWidget {
  const SkeletonPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(size: 26),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 15, borderRadius: 7)),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(borderRadius: 10, height: 48),
        ],
      ),
    );
  }
}

/// Daftar skeleton dengan SATU sapuan kilau (lebih murah & selaras).
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final double gap;

  const SkeletonList({
    super.key,
    this.itemCount = 3,
    required this.itemBuilder,
    this.gap = 12,
  });

  /// Varian baris aktivitas generik.
  const SkeletonList.tiles({super.key, this.itemCount = 3, this.gap = 0})
      : itemBuilder = _tileBuilder;

  /// Varian kartu form (kolom tunggal).
  const SkeletonList.cards({super.key, this.itemCount = 3, this.gap = 12})
      : itemBuilder = _cardBuilder;

  /// Mirror daftar aktivitas beranda (ikon + judul + kode, ber-divider).
  const SkeletonList.activity({super.key, this.itemCount = 3, this.gap = 0})
      : itemBuilder = _activityBuilder;

  /// Mirror daftar respons form (kartu expandable, gap 12).
  const SkeletonList.responses({super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _responseBuilder;

  /// Mirror daftar responden analisis (kartu radius 16, gap 12).
  const SkeletonList.respondents(
      {super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _respondentBuilder;

  /// Mirror daftar kelola admin (kartu radius 20, gap 12).
  const SkeletonList.admin({super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _adminBuilder;

  /// Mirror daftar umpan balik (kartu radius 12, gap 12).
  const SkeletonList.feedback({super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _feedbackBuilder;

  /// Mirror daftar attempt riwayat (kartu radius 14, gap 12).
  const SkeletonList.attempts({super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _attemptBuilder;

  /// Mirror daftar kelola soal (kartu radius 16 + border, gap 12).
  const SkeletonList.questions({super.key, this.itemCount = 4, this.gap = 12})
      : itemBuilder = _questionBuilder;

  /// Mirror daftar sesi monitoring (kartu radius 16, gap 10).
  const SkeletonList.sessions({super.key, this.itemCount = 4, this.gap = 10})
      : itemBuilder = _sessionBuilder;

  /// Mirror daftar pratinjau soal (kartu radius 16, gap 12).
  const SkeletonList.preview({super.key, this.itemCount = 3, this.gap = 12})
      : itemBuilder = _previewBuilder;

  /// Mirror isi tab Analisis: strip ringkasan + 2 kartu diagram.
  const SkeletonList.analyticsTab({super.key})
      : itemCount = 3,
        gap = 12,
        itemBuilder = _analyticsTabBuilder;

  static Widget _tileBuilder(int _) => const SkeletonListTile();
  static Widget _cardBuilder(int _) => const SkeletonFormCard();
  static Widget _activityBuilder(int i) =>
      const SkeletonActivityRow(showDivider: true);
  static Widget _responseBuilder(int _) => const SkeletonResponseCard();
  static Widget _respondentBuilder(int _) => const SkeletonRespondentCard();
  static Widget _adminBuilder(int _) => const SkeletonAdminCard();
  static Widget _feedbackBuilder(int _) => const SkeletonFeedbackCard();
  static Widget _attemptBuilder(int _) => const SkeletonAttemptCard();
  static Widget _questionBuilder(int _) => const SkeletonQuestionCard();
  static Widget _sessionBuilder(int _) => const SkeletonSessionCard();
  static Widget _previewBuilder(int _) => const SkeletonPreviewCard();
  static Widget _analyticsTabBuilder(int i) => switch (i) {
        0 => const SkeletonSummaryStrip(),
        _ => const SkeletonChartCard(),
      };

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) SizedBox(height: gap),
            itemBuilder(i),
          ],
        ],
      ),
    );
  }
}

/// Grid skeleton kartu form — mirror [ResponsiveGrid] di daftar form
/// (1 kolom phone, 2/3/4 di tablet/desktop, spacing 16).
class SkeletonFormGrid extends StatelessWidget {
  final int itemCount;
  final int Function(double width)? columnCountFor;
  final bool compact;

  const SkeletonFormGrid({
    super.key,
    this.itemCount = 4,
    this.columnCountFor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ResponsiveGrid(
        compact: compact,
        columnCountFor: columnCountFor,
        children: [
          for (var i = 0; i < itemCount; i++) const SkeletonFormCard(),
        ],
      ),
    );
  }
}
