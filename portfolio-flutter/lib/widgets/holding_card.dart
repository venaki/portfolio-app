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

  const HoldingCard({
    super.key,
    required this.holding,
    required this.quote,
    required this.exchangeRate,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: ticker + badge + name
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayTicker,
                        style: const TextStyle(
                          fontSize: 14,
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
                        holding.account,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                  ],
                ),
                if (displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      displayName,
                      style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Right: metrics in a row
          Expanded(
            child: Row(
              children: [
                _cell('현재가', hasQuote ? fmtPrice(price) : '-',
                    sub: hasQuote ? formatPercent(changePct) : null,
                    subColor: hasQuote ? dailyColor : null),
                _cell('수익', hasQuote ? '${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}' : '-',
                    sub: hasQuote ? formatPercent(profitPct) : null,
                    valueColor: hasQuote ? profitColor : null,
                    subColor: hasQuote ? profitColor : null),
                _cell('평단가', fmtPrice(holding.avgCost)),
                _cell('수량', '${formatShares(holding.shares)}주'),
                _cell('평가금액', hasQuote ? formatKRW(totalValueKRW) : '-'),
                if (!isKRW)
                  _cell('매입환율', formatKRW(holding.avgExchangeRate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, {String? sub, Color? valueColor, Color? subColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFFAAAAAA),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  sub,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: subColor ?? const Color(0xFF1A1A1A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
