import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Item tab pada segmented control respons
class ResponseTabItem {
  final IconData icon;
  final String label;

  const ResponseTabItem({required this.icon, required this.label});
}

/// Segmented control Riwayat / Analisis
/// - Animasi slider background mengikuti tab aktif
/// - Mendukung gesture swipe untuk mengganti tab
class ResponseTabSwitcher extends StatefulWidget {
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
  State<ResponseTabSwitcher> createState() => _ResponseTabSwitcherState();
}

class _ResponseTabSwitcherState extends State<ResponseTabSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(
      begin: widget.activeIndex.toDouble(),
      end: widget.activeIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void didUpdateWidget(ResponseTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      _slideAnimation = Tween<double>(
        begin: oldWidget.activeIndex.toDouble(),
        end: widget.activeIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow(),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - (widget.items.length - 1) * 4) /
              widget.items.length;

          return Stack(
            children: [
              // Animated slider background
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final position = _slideAnimation.value * (tabWidth + 4);
                  return Positioned(
                    left: position,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kAuthPrimary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: kAuthPrimary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Tab buttons
              Row(
                children: [
                  for (final tab in widget.items.asMap().entries) ...[
                    if (tab.key != 0) const SizedBox(width: 4),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          splashColor: kAuthPrimary.withOpacity(0.1),
                          highlightColor: kAuthPrimary.withOpacity(0.05),
                          onTap: () => widget.onChanged(tab.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    tab.value.icon,
                                    key: ValueKey<bool>(
                                      widget.activeIndex == tab.key,
                                    ),
                                    size: 16,
                                    color: widget.activeIndex == tab.key
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab.value.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: kFontBold,
                                    color: widget.activeIndex == tab.key
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}