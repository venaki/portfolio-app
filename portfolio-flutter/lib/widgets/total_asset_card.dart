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
    final accentColor = Theme.of(context).colorScheme.primary;
    final isWide = MediaQuery.of(context).size.width >= 768;

    final now = DateTime.now();
    final dateText = '${now.year}년 ${now.month}월 ${now.day}일';

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
          if (isWide)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatKRW(widget.totalValueKRW),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('USD', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                    Text(formatUSD(widget.totalValueUSD),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                  ],
                ),
              ],
            )
          else
            Text(
              formatKRW(widget.totalValueKRW),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            ),
          const SizedBox(height: 12),

          // Row 1: 일간변동 (어제 대비) — 항상 표시
          _buildChangeRow(
            changeKRW: widget.dailyChangeKRW,
            changePct: widget.dailyChangePct,
            color: dailyColor,
            isPositive: isDailyPositive,
            label: '어제',
          ),

          // 펼침 시 추가 정보
          if (_expanded) ...[
            const SizedBox(height: 8),

            // 구분선
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // 원금 대비 뱃지 + 원금 금액 (같은 줄)
            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: _buildChangeRow(
                      changeKRW: widget.totalProfitKRW,
                      changePct: widget.totalProfitPct,
                      color: profitColor,
                      isPositive: isProfitPositive,
                      label: '원금 대비',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Text('원금', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      const SizedBox(width: 8),
                      Text(formatKRW(widget.totalCostKRW),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                    ],
                  ),
                ],
              )
            else ...[
              _buildChangeRow(
                changeKRW: widget.totalProfitKRW,
                changePct: widget.totalProfitPct,
                color: profitColor,
                isPositive: isProfitPositive,
                label: '원금 대비',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('원금', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  Text(formatKRW(widget.totalCostKRW),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('USD', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  Text(formatUSD(widget.totalValueUSD),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                ],
              ),
            ],
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

  /// 수익금 뱃지 + 수익률 텍스트 + 라벨
  Widget _buildChangeRow({
    required double changeKRW,
    required double changePct,
    required Color color,
    required bool isPositive,
    required String label,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 수익금 뱃지
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
        // 수익률 텍스트 (뱃지 아님)
        Text(
          formatPercent(changePct),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
      ],
    );
  }
}
