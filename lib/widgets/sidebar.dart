import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const Sidebar({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    _SidebarItem(icon: Icons.home_outlined, label: '대시보드'),
    _SidebarItem(icon: Icons.bar_chart, label: '포트폴리오'),
    _SidebarItem(icon: Icons.schedule, label: '거래내역'),
    _SidebarItem(icon: Icons.account_balance_wallet_outlined, label: '기타 자산'),
    _SidebarItem(icon: Icons.settings_outlined, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(right: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          GestureDetector(
            onTap: () => onTap(0),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Row(
                children: [
                  Icon(Icons.show_chart, size: 20, color: accentColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Portfolio',
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Nav items
          ...List.generate(_items.length, (i) {
            final isActive = i == currentIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _items[i].icon,
                        size: 18,
                        color: isActive ? Colors.white : const Color(0xFF888888),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem({required this.icon, required this.label});
}
