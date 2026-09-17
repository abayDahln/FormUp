import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_up/core/widgets/responsive.dart';

/// Regression: di layar desktop/tablet AdaptiveSheet memakai Dialog. Builder
/// yang mengelola scroll sendiri (`selfScrolling`, mis. DraggableScrollableSheet
/// + `Expanded`) TIDAK boleh dibungkus SingleChildScrollView — kalau dibungkus,
/// tingginya jadi tak terbatas dan layout gagal, sehingga preview impor soal
/// tampil kosong di Windows.
void main() {
  Future<BuildContext> pumpHost(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    return ctx;
  }

  testWidgets('desktop: sheet selfScrolling (preview impor) tetap tampil',
      (tester) async {
    final ctx = await pumpHost(tester, const Size(1400, 900));

    AdaptiveSheet.show<void>(
      context: ctx,
      isScrollControlled: true,
      selfScrolling: true,
      builder: (sheetCtx, controller) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, inner) => Column(
          children: [
            const Text('PREVIEW-HEADER'),
            Expanded(
              child: ListView(
                controller: inner,
                children: const [Text('PREVIEW-ITEM')],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PREVIEW-HEADER'), findsOneWidget);
    expect(find.text('PREVIEW-ITEM'), findsOneWidget);
  });

  testWidgets('phone: sheet selfScrolling tetap tampil (bottom sheet)',
      (tester) async {
    final ctx = await pumpHost(tester, const Size(400, 800));

    AdaptiveSheet.show<void>(
      context: ctx,
      isScrollControlled: true,
      selfScrolling: true,
      builder: (sheetCtx, controller) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, inner) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: inner,
                children: const [Text('PREVIEW-ITEM')],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PREVIEW-ITEM'), findsOneWidget);
  });

  testWidgets('desktop: konten non-scrolling dibungkus scroll view',
      (tester) async {
    final ctx = await pumpHost(tester, const Size(1400, 900));

    AdaptiveSheet.show<void>(
      context: ctx,
      builder: (sheetCtx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 60; i++) Text('BARIS-$i'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('BARIS-0'), findsOneWidget);
  });
}