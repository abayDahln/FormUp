import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Opsi pengurutan daftar form
enum FormSort { newest, oldest, mostResponses, leastResponses }

extension FormSortLabel on FormSort {
  String get label => switch (this) {
        FormSort.newest => 'Terbaru',
        FormSort.oldest => 'Terlama',
        FormSort.mostResponses => 'Respon Terbanyak',
        FormSort.leastResponses => 'Respon Terdikit',
      };
}

/// Terapkan pencarian, filter tanggal, dan urutan pada daftar form.
List<FormData> filterForms(
  List<FormData> myForms,
  String searchQuery,
  DateTime? filterDate,
  FormSort sort,
) {
  var list = List<FormData>.from(myForms);

  final q = searchQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    list = list
        .where((f) => richToPlainText(f.title).toLowerCase().contains(q))
        .toList();
  }

  if (filterDate != null) {
    final target = filterDate;
    list = list.where((f) {
      final d = f.createdAt ?? f.updatedAt;
      return d != null &&
          d.year == target.year &&
          d.month == target.month &&
          d.day == target.day;
    }).toList();
  }

  switch (sort) {
    case FormSort.newest:
      list.sort((a, b) =>
          (b.createdAt ?? b.updatedAt ?? DateTime(0))
              .compareTo(a.createdAt ?? a.updatedAt ?? DateTime(0)));
    case FormSort.oldest:
      list.sort((a, b) =>
          (a.createdAt ?? a.updatedAt ?? DateTime(0))
              .compareTo(b.createdAt ?? b.updatedAt ?? DateTime(0)));
    case FormSort.mostResponses:
      list.sort((a, b) => b.responseCount.compareTo(a.responseCount));
    case FormSort.leastResponses:
      list.sort((a, b) => a.responseCount.compareTo(b.responseCount));
  }

  return list;
}
