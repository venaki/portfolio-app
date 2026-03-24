import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'change_row.dart';

class AccountCard extends StatelessWidget {
  final String account;
  final Color color;
  final double valueKRW;
  final double valueUSD;
  final double dailyChangeKRW;
  final double dailyChangePct;
  final double profitKRW;
  final double profitPct;
  /// 서브카테고리별 평가금액 (미국/한국/기타)
  final Map<String, double> subCategories;

  const AccountCard({
    super.key,
    required this.account,
    required this.color,
    required this.valueKRW,
    required this.valueUSD,
    required this.dailyChangeKRW,
    required this.dailyChangePct,
    required this.profitKRW,
    required this.profitPct,
    this.subCategories = const {},
  });

  @override
  Widget build(BuildContext context) {
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
          // Row 1: account name (좌) + 오늘 변동 (우)
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
              ChangeRow(
                changeKRW: dailyChangeKRW,
                changePct: dailyChangePct,
                label: '오늘',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: balance
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
