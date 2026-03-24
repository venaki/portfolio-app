import 'package:flutter/material.dart';
import '../utils/format.dart';

class AccountCard extends StatelessWidget {
  final String account;
  final Color color;
  final double valueKRW;
  final double valueUSD;
  final double profitPercentKRW;
  /// 서브카테고리별 평가금액 (미국/한국/기타)
  final Map<String, double> subCategories;

  const AccountCard({
    super.key,
    required this.account,
    required this.color,
    required this.valueKRW,
    required this.valueUSD,
    required this.profitPercentKRW,
    this.subCategories = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = profitPercentKRW >= 0;
    final profitColor = isProfit ? const Color(0xFF16A34A) : const Color(0xFFE07B54);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: dot + name + percent
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    account,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

          // Value: KRW + USD
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatKRW(valueKRW),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 8),
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

          // Sub categories
          if (subCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...subCategories.entries.map((e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                  Text(
                    formatKRW(e.value),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
