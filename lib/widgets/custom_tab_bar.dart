import 'package:flutter/material.dart';

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, label: '홈'),
    _TabItem(icon: Icons.bar_chart, label: '포트폴리오'),
    _TabItem(icon: Icons.receipt_long_outlined, label: '거래내역'),
    _TabItem(icon: Icons.account_balance_wallet_outlined, label: '기타자산'),
    _TabItem(icon: Icons.settings_outlined, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      indicatorColor: accentColor.withValues(alpha: 0.16),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: _tabs
          .map(
            (item) =>
                NavigationDestination(icon: Icon(item.icon), label: item.label),
          )
          .toList(),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
