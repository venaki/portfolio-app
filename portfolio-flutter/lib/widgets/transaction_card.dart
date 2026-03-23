import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final typeLabel = _typeLabel(tx.type);
    final typeColor = _typeColor(tx.type);
    final totalAmount = tx.shares * tx.price;
    final isUSD = tx.currency == Currency.usd;
    final marketLabel = tx.market == Market.us
        ? 'US'
        : tx.market == Market.krx
            ? 'KRX'
            : 'KOSDAQ';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Type tag + Ticker + Account tag + Market tag
            Row(
              children: [
                // Type tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ticker
                Text(
                  tx.ticker,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 6),
                // Account tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tx.account,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D6E6E),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Market tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    marketLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
                const Spacer(),
                // Total amount
                Text(
                  isUSD ? formatUSD(totalAmount) : formatKRW(totalAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: shares · price · exchange rate
            Row(
              children: [
                Text(
                  '${formatShares(tx.shares)}주 · ${isUSD ? formatUSD(tx.price) : formatKRW(tx.price)}'
                  '${isUSD ? ' · ₩${formatShares(tx.exchangeRate)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
                const Spacer(),
                // Cost basis in KRW (for USD stocks)
                if (isUSD)
                  Text(
                    formatKRW(totalAmount * tx.exchangeRate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: date
            Text(
              tx.date,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.buy:
        return '매수';
      case TransactionType.sell:
        return '매도';
      case TransactionType.openingBalance:
        return '초기';
      case TransactionType.adjustment:
        return '조정';
    }
  }

  Color _typeColor(TransactionType type) {
    switch (type) {
      case TransactionType.buy:
        return const Color(0xFF0D6E6E);
      case TransactionType.sell:
        return const Color(0xFFE07B54);
      case TransactionType.openingBalance:
        return const Color(0xFF888888);
      case TransactionType.adjustment:
        return const Color(0xFF888888);
    }
  }
}
