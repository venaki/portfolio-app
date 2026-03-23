import 'package:flutter/material.dart';
import '../utils/format.dart';

class TotalAssetCard extends StatefulWidget {
  final double totalValueKRW;
  final double totalValueUSD;
  final double dailyChangeKRW;
  final double dailyChangePct;
  final double totalCostKRW;
  final double totalProfitKRW;
  final double totalProfitPct;

  const TotalAssetCard({
    super.key,
    required this.totalValueKRW,
    required this.totalValueUSD,
    required this.dailyChangeKRW,
    required this.dailyChangePct,
    required this.totalCostKRW,
    required this.totalProfitKRW,
    required this.totalProfitPct,
  });

  @override
  State<TotalAssetCard> createState() => _TotalAssetCardState();
}

class _TotalAssetCardState extends State<TotalAssetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDailyPositive = widget.dailyChangeKRW >= 0;
    final isProfitPositive = widget.totalProfitKRW >= 0;
    const positive = Color(0xFF16A34A);
    const negative = Color(0xFFE07B54);
    final dailyColor = isDailyPositive ? positive : negative;
    final profitColor = isProfitPositive ? positive : negative;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: TOTAL ASSETS label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: const Color(0xFFAAAAAA),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total value row: KRW (left) + USD (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatKRW(widget.totalValueKRW),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  formatUSD(widget.totalValueUSD),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Daily change row
            Row(
              children: [
                Text(
                  '어제 대비',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDailyPositive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDailyPositive ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: dailyColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatKRW(widget.dailyChangeKRW.abs()),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dailyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatPercent(widget.dailyChangePct),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dailyColor,
                  ),
                ),
              ],
            ),

            // Expanded section: cost + profit
            if (_expanded) ...[
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: const Color(0xFFF0F0F0),
              ),
              const SizedBox(height: 16),

              // Cost
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '투자 원금',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  Text(
                    formatKRW(widget.totalCostKRW),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total profit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '원금 대비 수익',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  Row(
                    children: [
                      Text(
                        formatKRW(widget.totalProfitKRW),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatPercent(widget.totalProfitPct),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
