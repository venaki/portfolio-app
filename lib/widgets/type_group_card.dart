import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

/// By Type 뷰의 개별 종목/자산 항목
class HoldingRow {
  final String name;
  final String ticker;
  final double valueKRW;
  final double costKRW;
  final double dailyChangeKRW;
  final double yestValueKRW;

  const HoldingRow({
    required this.name,
    required this.ticker,
    required this.valueKRW,
    required this.costKRW,
    required this.dailyChangeKRW,
    required this.yestValueKRW,
  });

  double get profitKRW => valueKRW - costKRW;
  double get profitPct => costKRW > 0 ? (profitKRW / costKRW) * 100 : 0.0;
}

/// Asset Type 그룹 카드 (미국주식, 한국주식, 예금 등)
class TypeGroupCard extends StatelessWidget {
  final String title;
  final List<HoldingRow> items;

  const TypeGroupCard({
    super.key,
    required this.title,
    required this.items,
  });

  double get totalValue => items.fold(0.0, (s, e) => s + e.valueKRW);
  double get totalCost => items.fold(0.0, (s, e) => s + e.costKRW);
  double get totalProfit => totalValue - totalCost;
  double get totalProfitPct => totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0;
  double get totalDailyChange => items.fold(0.0, (s, e) => s + e.dailyChangeKRW);
  double get totalYestValue => items.fold(0.0, (s, e) => s + e.yestValueKRW);
  double get totalDailyPct => totalYestValue > 0 ? (totalDailyChange / totalYestValue) * 100 : 0.0;

  @override
  Widget build(BuildContext context) {
    final profitColor = totalProfit >= 0 ? positiveColor : negativeColor;

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
          // 그룹 헤더: 타이틀 + 소계
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatKRW(totalValue),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (totalProfit != 0)
                    Text(
                      '${totalProfit >= 0 ? '+' : ''}${formatKRW(totalProfit)} (${formatPercent(totalProfitPct)})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: profitColor,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 개별 항목
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ...items.map((item) => _buildItemRow(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(HoldingRow item) {
    final profitColor = item.profitKRW >= 0 ? positiveColor : negativeColor;
    final dailyPct = item.yestValueKRW > 0
        ? (item.dailyChangeKRW / item.yestValueKRW) * 100
        : 0.0;
    final dailyColor = item.dailyChangeKRW >= 0 ? positiveColor : negativeColor;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 종목명 + 티커
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.ticker != item.name)
                  Text(
                    item.ticker,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                  ),
              ],
            ),
          ),
          // 평가금액 + 수익
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatKRW(item.valueKRW),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (item.costKRW > 0)
                  Text(
                    '${item.profitKRW >= 0 ? '+' : ''}${formatKRW(item.profitKRW)} (${formatPercent(item.profitPct)})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: profitColor,
                    ),
                  ),
                if (item.dailyChangeKRW != 0)
                  Text(
                    '오늘 ${item.dailyChangeKRW >= 0 ? '+' : ''}${formatKRW(item.dailyChangeKRW)} (${formatPercent(dailyPct)})',
                    style: TextStyle(fontSize: 10, color: dailyColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
