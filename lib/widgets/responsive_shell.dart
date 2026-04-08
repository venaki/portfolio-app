import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sidebar.dart';
import 'custom_tab_bar.dart';
import '../providers/filter_provider.dart';

class ResponsiveShell extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  static const breakpoint = 1024.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= breakpoint;
    final isEditMode = ref.watch(portfolioEditModeProvider);

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
        if (!isEditMode)
          CustomTabBar(currentIndex: currentIndex, onTap: onTap),
      ],
    );
  }
}
