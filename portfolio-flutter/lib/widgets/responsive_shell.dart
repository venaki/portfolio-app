import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'custom_tab_bar.dart';

class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  static const breakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= breakpoint;

    if (isDesktop) {
      return Row(
        children: [
          Sidebar(currentIndex: currentIndex, onTap: onTap),
          Expanded(child: child),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: child),
        CustomTabBar(currentIndex: currentIndex, onTap: onTap),
      ],
    );
  }
}
