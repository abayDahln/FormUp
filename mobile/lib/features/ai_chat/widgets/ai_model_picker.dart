import 'package:flutter/material.dart';
import 'package:form_up/core/services/gemini_service.dart';

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
      offset: const Offset(0, -180),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBDC9C8)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF018081)),
          const SizedBox(width: 6),
          Text(
            GeminiService.selectedModelDisplay.replaceAll('Gemini ', ''),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black54),
        ]),
      ),
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
