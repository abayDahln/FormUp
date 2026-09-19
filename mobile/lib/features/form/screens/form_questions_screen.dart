import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/questions_panel.dart';

/// Kelola daftar soal form — layar tunggal phone (panel penuh).
/// Tablet/desktop: [FormEditorScreen] dual panel (pengaturan + soal).
class FormQuestionsScreen extends StatefulWidget {
  final int? formId;

  const FormQuestionsScreen({super.key, required this.formId});

  @override
  State<FormQuestionsScreen> createState() => _FormQuestionsScreenState();
}

class _FormQuestionsScreenState extends State<FormQuestionsScreen> {
  final GlobalKey<QuestionsPanelState> _panelKey =
      GlobalKey<QuestionsPanelState>();
  AppRouterDelegate? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_guard);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    super.dispose();
  }

  Future<bool> _guard() async {
    final panel = _panelKey.currentState;
    if (panel == null) return true;
    return panel.confirmExit();
  }

  @override
  Widget build(BuildContext context) {
    return QuestionsPanel(
      key: _panelKey,
      formId: widget.formId,
      onSaved: (formId) async {
        if (!mounted) return;
        AppRouter.of(context).pop(formId);
      },
    );
  }
}
