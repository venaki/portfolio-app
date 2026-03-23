import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final String? stockName;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.stockName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final badge = _getBadge(tx.type);
    final isKRW = tx.currency == Currency.krw;
    final isKR = tx.market == Market.krx || tx.market == Market.kosdaq;

    final totalNative = tx.shares * tx.price;
    final totalKRW = isKRW ? totalNative : totalNative * tx.exchangeRate;

    // 한국 주식은 종목명, 미국 주식은 티커
    final displayTicker = isKR && stockName != null && stockName!.isNotEmpty
        ? stockName!
        : tx.ticker;

    // 디테일 라인
    final detailText = isKRW
        ? '${formatShares(tx.shares)}주 × ${formatKRW(tx.price)}'
        : '${formatShares(tx.shares)}주 × ${formatUSD(tx.price)} · ₩${formatShares(tx.exchangeRate)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: badge + ticker + owner
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: badge.color,
                          ),
                        ),
                      ),
                      // Ticker / Name
                      Text(
                        displayTicker,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      // Owner badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.account,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Detail line
                  Text(
                    detailText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Date
                  Text(
                    tx.date,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ),

            // Right side: amounts
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isKRW ? formatKRW(totalKRW) : formatUSD(totalNative),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (!isKRW) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatKRW(totalKRW),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  _BadgeConfig _getBadge(TransactionType type) {
    switch (type) {
      case TransactionType.buy:
      case TransactionType.openingBalance:
      case TransactionType.adjustment:
        return _BadgeConfig(
          bg: const Color(0xFFE8F5E9),
          color: positiveColor,
          label: type == TransactionType.buy ? '매수' : type == TransactionType.openingBalance ? '초기' : '조정',
        );
      case TransactionType.sell:
        return _BadgeConfig(
          bg: const Color(0xFFFFF0EB),
          color: negativeColor,
          label: '매도',
        );
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color color;
  final String label;
  const _BadgeConfig({required this.bg, required this.color, required this.label});
}
