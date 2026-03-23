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

    String formatPrice(double v) => isKRW ? formatKRW(v) : formatUSD(v);

    // 한국 주식은 종목명을 티커로, 미국 주식은 티커를 티커로
    final displayTicker = isKR && quote?.name != null && quote!.name.isNotEmpty
        ? quote!.name
        : holding.ticker;
    final displayName = isKR
        ? holding.ticker
        : (quote?.name ?? '');

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
          // Top row: ticker + badge / price + daily change
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: ticker + owner badge
              Row(
                children: [
                  Text(
                    displayTicker,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      holding.account,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ),
                ],
              ),
              // Right: price + daily change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasQuote ? formatPrice(price) : '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (hasQuote)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatPercent(changePct),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: dailyColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Sub title (name)
          if (displayName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              displayName,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // Grid: 수익 / 평단가 / 수량 / 평가금액 / 매입환율
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 수익
              _gridItem(
                '수익',
                hasQuote ? '${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}' : '-',
                sub: hasQuote ? formatPercent(profitPct) : null,
                valueColor: hasQuote ? profitColor : null,
              ),
              // 평단가
              _gridItem(
                '평단가',
                formatPrice(holding.avgCost),
              ),
              // 수량
              _gridItem(
                '수량',
                '${formatShares(holding.shares)}주',
              ),
              // 평가금액
              _gridItem(
                '평가금액',
                hasQuote ? formatKRW(totalValueKRW) : '-',
              ),
              // 매입환율 (USD only)
              if (!isKRW)
                _gridItem(
                  '매입환율',
                  formatKRW(holding.avgExchangeRate),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridItem(String label, String value, {String? sub, Color? valueColor}) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF1A1A1A),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
