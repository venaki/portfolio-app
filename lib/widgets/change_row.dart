import 'package:flutter/material.dart';
import '../utils/format.dart';

/// 수익금 뱃지 + 수익률 텍스트 + 라벨 (공용)
class ChangeRow extends StatelessWidget {
  final double changeKRW;
  final double changePct;
  final String label;

  const ChangeRow({
    super.key,
    required this.changeKRW,
    required this.changePct,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = changeKRW >= 0;
    final color = isPositive ? const Color(0xFF16A34A) : const Color(0xFFE07B54);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFBE9E7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${isPositive ? '+' : ''}${formatKRW(changeKRW)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        Text(
          formatPercent(changePct),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
      ],
    );
  }
}
