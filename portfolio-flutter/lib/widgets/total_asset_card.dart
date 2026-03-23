import 'package:flutter/material.dart';
import '../utils/format.dart';

class TotalAssetCard extends StatelessWidget {
  final double totalValueKRW;
  final double totalProfitKRW;
  final double totalProfitPercentKRW;

  const TotalAssetCard({
    super.key,
    required this.totalValueKRW,
    required this.totalProfitKRW,
    required this.totalProfitPercentKRW,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = totalProfitKRW >= 0;
    const profitPositive = Color(0xFF0D6E6E);
    const profitNegative = Color(0xFFE07B54);
    final profitColor = isProfit ? profitPositive : profitNegative;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL ASSETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatKRW(totalValueKRW),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isProfit ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: profitColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatKRW(totalProfitKRW.abs()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: profitColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                formatPercent(totalProfitPercentKRW),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: profitColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
