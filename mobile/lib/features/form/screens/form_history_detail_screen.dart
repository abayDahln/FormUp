import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/features/form/widgets/history_answer_card.dart';
import 'package:form_up/features/form/widgets/history_summary_header.dart';

/// Detail hasil pengerjaan form
class FormHistoryDetailScreen extends StatefulWidget {
  final String formLink;
  final int responseId;

  const FormHistoryDetailScreen({
    super.key,
    required this.formLink,
    required this.responseId,
  });

  @override
  State<FormHistoryDetailScreen> createState() =>
      _FormHistoryDetailScreenState();
}

class _FormHistoryDetailScreenState extends State<FormHistoryDetailScreen> {
  bool _loading = true;
  PublicFormResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await PublicFormService.getResult(
        widget.formLink,
        widget.responseId,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        title:  Text(
          "Detail Riwayat",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingOverlay()
          : AuthBackground(plain: true,
              child: SafeArea(
                child: _result == null
                    ?  Center(
                        child: Text(
                          "Hasil tidak tersedia.",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : _buildContent(_result!),
              ),
            ),
    );
  }

  Widget _buildContent(PublicFormResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistorySummaryHeader(result: result),
          const SizedBox(height: 16),
          Text(
            result.showScore ? "Pembahasan" : "Jawaban Anda",
            style:  TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (result.answers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child:  Text(
                "Belum ada jawaban.",
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (var i = 0; i < result.answers.length; i++) ...[
              HistoryAnswerCard(
                index: i,
                answer: result.answers[i],
                showScore: result.showScore,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

