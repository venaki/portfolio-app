import 'package:flutter/material.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../engine/calculations.dart';
import '../utils/format.dart';

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
    final valueKRW = calcTotalValueKRW(holding, price, exchangeRate);
    final changePct = quote?.changePct ?? 0;
    final isPositive = changePct >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          // Left side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      holding.ticker,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6E6E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        holding.account,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quote?.name ?? holding.ticker,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatShares(holding.shares)}주 · 평단 ${holding.currency == Currency.usd ? formatUSD(holding.avgCost) : formatKRW(holding.avgCost)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),
          // Right side
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                holding.currency == Currency.usd
                    ? formatUSD(price)
                    : formatKRW(price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatPercent(changePct),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPositive
                      ? const Color(0xFF0D6E6E)
                      : const Color(0xFFE07B54),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatKRW(valueKRW),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
