import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

const feedbackReasons = <String>[
  'General Feedback',
  'Inappropriate Content',
  'Misleading Information',
  'Bug / Technical Issue',
];

/// Buka bottom sheet feedback; mengembalikan true bila terkirim.
Future<bool?> showFeedbackSheet(BuildContext context, {required int formId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FeedbackSheet(formId: formId),
  );
}

/// Bottom sheet feedback
class FeedbackSheet extends StatefulWidget {
  final int formId;

  const FeedbackSheet({super.key, required this.formId});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  String _reason = feedbackReasons.first;
  final _descController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      showAuthToast(context, 'Deskripsi feedback wajib diisi', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await FormService.submitFeedback(
        widget.formId,
        reason: _reason,
        description: desc,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kirim Feedback',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final r in feedbackReasons)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _reason = v);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Jelaskan feedback atau masalah Anda...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim Feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
