import 'package:flutter/material.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Judul header yang sekaligus pemilih model AI (gaya Gemini:
/// nama model + panah dropdown, ketuk untuk ganti model).
class AiModelPicker extends StatelessWidget {
  final VoidCallback? onChanged;
  const AiModelPicker({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: GeminiService.selectedModelDisplay,
      onSelected: (v) async {
        await GeminiService.setModel(v);
        onChanged?.call();
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: 'Pilih model AI',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(
            GeminiService.selectedModelDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: kFontBold, fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
      ]),
      itemBuilder: (ctx) => [
        for (final m in GeminiService.availableModels)
          PopupMenuItem<String>(
            value: m,
            child: Row(children: [
              Icon(m == GeminiService.selectedModelDisplay ? Icons.check : Icons.auto_awesome_outlined, size: 14, color: m == GeminiService.selectedModelDisplay ? const Color(0xFF018081) : Colors.black54),
              const SizedBox(width: 8),
              Text(m, style: TextStyle(fontSize: 12, fontWeight: m == GeminiService.selectedModelDisplay ? FontWeight.bold : FontWeight.normal, color: m == GeminiService.selectedModelDisplay ? const Color(0xFF018081) : Colors.black87)),
            ]),
          ),
      ],
    );
  }
}
