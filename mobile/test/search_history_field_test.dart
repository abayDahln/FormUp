import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/utils/search_history.dart';

/// Regresi: hapus 1 riwayat & hapus semua harus langsung hilang dari dropdown.
///
/// Penyebab lama: `_refreshOptions` memakai
/// `inner.value = inner.value.copyWith()` yang equal sehingga
/// ValueNotifier melewatkan notifyListeners — Autocomplete tidak pernah
/// membangun ulang opsi dan item terhapus tetap tampil.
void main() {
  Future<void> pumpSearchField(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            controller: TextEditingController(),
            onChanged: (_) {},
            hint: 'Cari...',
            historyKey: 'test_history',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Fokuskan field agar dropdown riwayat terbuka.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  testWidgets('hapus 1 riwayat menghilangkan item dari dropdown',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'test_history': ['satu', 'dua'],
    });
    await pumpSearchField(tester);

    expect(find.text('satu'), findsOneWidget);
    expect(find.text('dua'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus riwayat ini').first);
    await tester.pumpAndSettle();

    expect(find.text('satu'), findsNothing);
    expect(find.text('dua'), findsOneWidget);
    expect(await SearchHistory.get('test_history'), ['dua']);
  });

  testWidgets('hapus semua mengosongkan dropdown', (tester) async {
    SharedPreferences.setMockInitialValues({
      'test_history': ['satu', 'dua'],
    });
    await pumpSearchField(tester);

    expect(find.text('Hapus semua'), findsOneWidget);

    await tester.tap(find.text('Hapus semua'));
    await tester.pumpAndSettle();

    expect(find.text('satu'), findsNothing);
    expect(find.text('dua'), findsNothing);
    expect(await SearchHistory.get('test_history'), isEmpty);
  });
}
