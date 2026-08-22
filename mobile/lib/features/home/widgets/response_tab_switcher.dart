import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Item tab pada segmented control respons
class ResponseTabItem {
  final IconData icon;
  final String label;

  const ResponseTabItem({required this.icon, required this.label});
}

/// Segmented control Riwayat / Analisis
class ResponseTabSwitcher extends StatelessWidget {
  final List<ResponseTabItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const ResponseTabSwitcher({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow(),
      ),
      child: Row(
        children: [
          for (final tab in items.asMap().entries) ...[
            if (tab.key != 0) const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(tab.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: activeIndex == tab.key
                        ? kAuthPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.value.icon,
                        size: 16,
                        color:
                            activeIndex == tab.key ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.value.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: activeIndex == tab.key
                              ? Colors.white
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
