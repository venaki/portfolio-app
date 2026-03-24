import 'package:flutter/material.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../engine/calculations.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class HoldingCard extends StatelessWidget {
  final Holding holding;
  final StockQuote? quote;
  final double exchangeRate;
  final VoidCallback? onTap;

  const HoldingCard({
    super.key,
    required this.holding,
    required this.quote,
    required this.exchangeRate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = quote?.price ?? 0;
    final changePct = quote?.changePct ?? 0;
    final isKRW = holding.currency == Currency.krw;
    final isKR = holding.market == Market.krx || holding.market == Market.kosdaq;
    final hasQuote = quote != null && price > 0;

    final totalValueKRW = calcTotalValueKRW(holding, price, exchangeRate);
    final profitKRW = calcProfitKRW(holding, price, exchangeRate);
    final profitPct = calcProfitPercentKRW(holding, price, exchangeRate);

    final dailyColor = changePct >= 0 ? positiveColor : negativeColor;
    final profitColor = profitKRW >= 0 ? positiveColor : negativeColor;

    String fmtPrice(double v) => isKRW ? formatKRW(v) : formatUSD(v);

    final displayTicker = isKR && quote?.name != null && quote!.name.isNotEmpty
        ? quote!.name
        : holding.ticker;
    final displayName = isKR ? holding.ticker : (quote?.name ?? '');
    final marketLabel = isKR ? '한국' : '미국';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: ticker + badge | current price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: ticker + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayTicker,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            marketLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (displayName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          displayName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Right: current price + daily change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasQuote ? fmtPrice(price) : '-',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (hasQuote)
                    Text(
                      formatPercent(changePct),
                      style: TextStyle(fontSize: 11, color: dailyColor),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: profit amount + percent
          Row(
            children: [
              Text(
                hasQuote ? '${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}' : '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasQuote ? profitColor : const Color(0xFF1A1A1A),
                ),
              ),
              if (hasQuote) ...[
                const SizedBox(width: 6),
                Text(
                  formatPercent(profitPct),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: profitColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Row 3: 평단가 x 수량
          Text(
            '${fmtPrice(holding.avgCost)}  x  ${formatShares(holding.shares)}주',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 8),
          // Row 4: 평가금액 + 매입환율
          Row(
            children: [
              Text(
                hasQuote ? formatKRW(totalValueKRW) : '-',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (!isKRW) ...[
                const SizedBox(width: 12),
                Text(
                  formatKRW(holding.avgExchangeRate),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
    );
  }
}
