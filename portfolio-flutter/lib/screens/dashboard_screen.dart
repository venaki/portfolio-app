import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../engine/calculations.dart';
import '../widgets/total_asset_card.dart';
import '../widgets/account_card.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);

    if (portfolio.isLoading && portfolio.holdings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 총자산 계산
    double totalValueKRW = 0;
    double totalCostKRW = 0;
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;

      totalValueKRW += calcTotalValueKRW(h, price, portfolio.exchangeRate);
      totalCostKRW += calcCostKRW(h);
    }

    // 기타 자산 합산
    for (final oa in portfolio.otherAssets) {
      final v = oa.currency == Currency.krw
          ? oa.value
          : oa.value * portfolio.exchangeRate;
      totalValueKRW += v;
      totalCostKRW += v;
    }

    final totalProfitKRW = totalValueKRW - totalCostKRW;
    final totalProfitPct = totalCostKRW > 0 ? (totalProfitKRW / totalCostKRW) * 100 : 0.0;

    // 계좌별 집계
    final accountMap = <String, ({double value, double cost})>{};
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final entry = accountMap[h.account] ?? (value: 0.0, cost: 0.0);
      accountMap[h.account] = (
        value: entry.value + calcTotalValueKRW(h, price, portfolio.exchangeRate),
        cost: entry.cost + calcCostKRW(h),
      );
    }
    for (final oa in portfolio.otherAssets) {
      final v = oa.currency == Currency.krw ? oa.value : oa.value * portfolio.exchangeRate;
      final entry = accountMap[oa.account] ?? (value: 0.0, cost: 0.0);
      accountMap[oa.account] = (value: entry.value + v, cost: entry.cost + v);
    }

    // 업데이트 시간 포맷 (HH:mm)
    String updateTimeText = '';
    if (portfolio.lastUpdated != null) {
      final t = portfolio.lastUpdated!;
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      updateTimeText = '$hh:$mm 업데이트';
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '자산 현황',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(portfolioProvider.notifier).refreshPrices(),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xFF888888),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          // Total Asset Card
          TotalAssetCard(
            totalValueKRW: totalValueKRW,
            totalProfitKRW: totalProfitKRW,
            totalProfitPercentKRW: totalProfitPct,
          ),
          const SizedBox(height: 12),

          // Meta Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 14,
                    color: Color(0xFF888888),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'USD/KRW ${formatKRW(portfolio.exchangeRate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              if (updateTimeText.isNotEmpty)
                Text(
                  updateTimeText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // BY ACCOUNT section label
          const Text(
            'BY ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 12),

          // Account Cards
          ...accountMap.entries.indexed.map((e) {
            final (index, entry) = e;
            final profit = entry.value.value - entry.value.cost;
            final pct = entry.value.cost > 0 ? (profit / entry.value.cost) * 100 : 0.0;
            final valueUSD = portfolio.exchangeRate > 0
                ? entry.value.value / portfolio.exchangeRate
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AccountCard(
                account: entry.key,
                color: getAccountColor(index),
                valueKRW: entry.value.value,
                valueUSD: valueUSD,
                profitPercentKRW: pct,
              ),
            );
          }),
        ],
      ),
    );
  }
}
