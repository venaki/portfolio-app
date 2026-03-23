import 'package:flutter/material.dart';
import '../utils/format.dart';

class AccountCard extends StatelessWidget {
  final String account;
  final Color color;
  final double valueKRW;
  final double valueUSD;
  final double profitPercentKRW;

  const AccountCard({
    super.key,
    required this.account,
    required this.color,
    required this.valueKRW,
    required this.valueUSD,
    required this.profitPercentKRW,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = profitPercentKRW >= 0;
    const profitPositive = Color(0xFF0D6E6E);
    const profitNegative = Color(0xFFE07B54);
    final profitColor = isProfit ? profitPositive : profitNegative;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    account,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                formatPercent(profitPercentKRW),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: profitColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatKRW(valueKRW),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                formatUSD(valueUSD),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
