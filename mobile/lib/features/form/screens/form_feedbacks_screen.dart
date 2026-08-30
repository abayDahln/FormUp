import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';

class FormFeedbacksScreen extends StatefulWidget {
  final int formId;
  final String formTitle;

  const FormFeedbacksScreen({
    super.key,
    required this.formId,
    required this.formTitle,
  });

  @override
  State<FormFeedbacksScreen> createState() => _FormFeedbacksScreenState();
}

class _FormFeedbacksScreenState extends State<FormFeedbacksScreen> {
  List<FormFeedbackItem> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FormService.getFormFeedbacks(widget.formId);
      if (!mounted) return;
      setState(() {
        _feedbacks = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
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
        shape: const Border(bottom: BorderSide(color: Color(0xCCBDC9C8))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: Text(
          'Umpan Balik Form',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator.circular())
          : AuthBackground(
              plain: true,
              child: SafeArea(
                child: _feedbacks.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.feedback_outlined, color: Colors.grey, size: 40),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada umpan balik untuk form ini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AppRefreshIndicator(
                        onRefresh: _load,
                        indicatorColor: kAuthPrimary,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _feedbacks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final fb = _feedbacks[index];
                            final localDate = fb.createdAt.toLocal();
                            final timeStr = "${localDate.day}/${localDate.month}/${localDate.year} "
                                "${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBDC9C8).withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fb.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: kFontBold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Kategori: ${fb.reason}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kAuthPrimary,
                                    ),
                                  ),
                                  if (fb.description != null && fb.description!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      fb.description!,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
    );
  }
}