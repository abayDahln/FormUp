import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: const Text(
          "Detail Riwayat",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(plain: true,
              child: SafeArea(
                child: _result == null
                    ? const Center(
                        child: Text(
                          "Hasil tidak tersedia.",
                          style: TextStyle(color: Colors.black54),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (result.answers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Belum ada jawaban.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
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

