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
    final accentColor = Theme.of(context).colorScheme.primary;
    final isWide = MediaQuery.of(context).size.width >= 768;

    final now = DateTime.now();
    final dateText = '${now.year}년 ${now.month}월 ${now.day}일';

    final dailyPositive = widget.dailyChangeKRW >= 0;
    final dailyColor = dailyPositive ? const Color(0xFF16A34A) : const Color(0xFFE07B54);
    final profitPositive = widget.totalProfitKRW >= 0;
    final profitColor = profitPositive ? const Color(0xFF16A34A) : const Color(0xFFE07B54);

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
          // 날짜
          Text(dateText, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 4),

          // TOTAL ASSETS label
          const Text(
            'TOTAL ASSETS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 8),

          // 총자산 KRW + USD
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatKRW(widget.totalValueKRW),
                style: TextStyle(fontSize: isWide ? 32 : 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 12),
              Text(
                formatUSD(widget.totalValueUSD),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 오늘 변동 (항상 표시)
          _buildChangeLabel(widget.dailyChangeKRW, widget.dailyChangePct, dailyColor, dailyPositive, '오늘'),

          // 펼침 시 추가 정보
          if (_expanded) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // 원금 대비 (좌) + 원금/USD 금액 (우)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좌: 수익금 + 수익률
                Expanded(
                  child: _buildChangeLabel(widget.totalProfitKRW, widget.totalProfitPct, profitColor, profitPositive, '원금'),
                ),
                // 우: 원금 + USD
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatKRW(widget.totalCostKRW),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                        const SizedBox(width: 6),
                        const Text('원금', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatUSD(widget.totalValueUSD),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                        const SizedBox(width: 6),
                        const Text('USD', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],

          // 펼치기/접기 버튼
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? '접기' : '펼치기',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeLabel(double amount, double pct, Color color, bool isPositive, String label) {
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
            '${isPositive ? '+' : ''}${formatKRW(amount)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        Text(
          formatPercent(pct),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
      ],
    );
  }
}
