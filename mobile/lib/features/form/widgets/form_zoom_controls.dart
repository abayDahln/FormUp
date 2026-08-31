import 'package:flutter/material.dart';
import 'package:form_up/core/utils/form_zoom.dart';

/// Tombol + / - zoom di kanan header. Width tetap kecil, pill style.
class FormZoomControls extends StatelessWidget {
  const FormZoomControls({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: formZoom,
      builder: (context, zoom, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomBtn(
              icon: Icons.zoom_out,
              tooltip: 'Perkecil',
              enabled: formZoom.canZoomOut,
              onTap: formZoom.zoomOut,
            ),
            const SizedBox(width: 2),
            _ZoomBtn(
              icon: Icons.zoom_in,
              tooltip: 'Perbesar',
              enabled: formZoom.canZoomIn,
              onTap: formZoom.zoomIn,
            ),
          ],
        );
      },
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        padding: EdgeInsets.zero,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFBDC9C8)),
        ),
        icon: Icon(icon, color: enabled ? Colors.black87 : Colors.black26),
      ),
    );
  }
}
