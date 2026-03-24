import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
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
      final raw = oa.category == AssetCategory.loan ? -oa.value.abs() : oa.value;
      final v = oa.currency == Currency.krw ? raw : raw * portfolio.exchangeRate;
      totalValueKRW += v;
      totalCostKRW += v;
    }

    final totalProfitKRW = totalValueKRW - totalCostKRW;
    final totalProfitPct = totalCostKRW > 0 ? (totalProfitKRW / totalCostKRW) * 100 : 0.0;
    final totalValueUSD = portfolio.exchangeRate > 0
        ? totalValueKRW / portfolio.exchangeRate
        : 0.0;

    // 어제 대비 일간 변동
    double dailyChangeKRW = 0;
    double totalYestValueKRW = 0;
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      dailyChangeKRW += calcDailyChangeKRW(h, price, closeYest, portfolio.exchangeRate);
      totalYestValueKRW += calcTotalValueKRW(h, closeYest, portfolio.exchangeRate);
    }
    final dailyChangePct = totalYestValueKRW > 0
        ? (dailyChangeKRW / totalYestValueKRW) * 100
        : 0.0;

    // 계좌별 집계 + 서브카테고리
    final accountMap = <String, ({double value, double cost, double dailyChange, double yestValue, double usValue, double krValue, double otherValue})>{};
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      final val = calcTotalValueKRW(h, price, portfolio.exchangeRate);
      final cost = calcCostKRW(h);
      final daily = calcDailyChangeKRW(h, price, closeYest, portfolio.exchangeRate);
      final yest = calcTotalValueKRW(h, closeYest, portfolio.exchangeRate);
      final isUS = h.market == Market.us;
      final isKR = h.market == Market.krx || h.market == Market.kosdaq;

      final entry = accountMap[h.account] ?? (value: 0.0, cost: 0.0, dailyChange: 0.0, yestValue: 0.0, usValue: 0.0, krValue: 0.0, otherValue: 0.0);
      accountMap[h.account] = (
        value: entry.value + val,
        cost: entry.cost + cost,
        dailyChange: entry.dailyChange + daily,
        yestValue: entry.yestValue + yest,
        usValue: entry.usValue + (isUS ? val : 0),
        krValue: entry.krValue + (isKR ? val : 0),
        otherValue: entry.otherValue,
      );
    }
    for (final oa in portfolio.otherAssets) {
      final raw = oa.category == AssetCategory.loan ? -oa.value.abs() : oa.value;
      final v = oa.currency == Currency.krw ? raw : raw * portfolio.exchangeRate;
      final entry = accountMap[oa.account] ?? (value: 0.0, cost: 0.0, dailyChange: 0.0, yestValue: 0.0, usValue: 0.0, krValue: 0.0, otherValue: 0.0);
      accountMap[oa.account] = (
        value: entry.value + v,
        cost: entry.cost + v,
        dailyChange: entry.dailyChange,
        yestValue: entry.yestValue + v,
        usValue: entry.usValue,
        krValue: entry.krValue,
        otherValue: entry.otherValue + v,
      );
    }

    // 업데이트 시간
    String updateTimeText = '';
    if (portfolio.lastUpdated != null) {
      final t = portfolio.lastUpdated!;
      updateTimeText = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 업데이트';
    }

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
        children: [
          // 리프레쉬 버튼
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => ref.read(portfolioProvider.notifier).refreshPrices(),
                child: const Icon(Icons.refresh, color: Color(0xFF888888), size: 20),
              ),
            ),
          ),

          // Total Asset Card
          TotalAssetCard(
            totalValueKRW: totalValueKRW,
            totalValueUSD: totalValueUSD,
            dailyChangeKRW: dailyChangeKRW,
            dailyChangePct: dailyChangePct,
            totalCostKRW: totalCostKRW,
            totalProfitKRW: totalProfitKRW,
            totalProfitPct: totalProfitPct,
          ),
          const SizedBox(height: 12),

          // Meta Row: exchange rate + update time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 USD = ${formatKRW(portfolio.exchangeRate)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
              ),
              if (updateTimeText.isNotEmpty)
                Text(
                  updateTimeText,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // BY ACCOUNT
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

          // Account Cards — PC: 가로 배열, Mobile: 세로 배열
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: accountMap.entries.indexed.map((e) {
                final (index, entry) = e;
                final v = entry.value;
                final profit = v.value - v.cost;
                final profitPct = v.cost > 0 ? (profit / v.cost) * 100 : 0.0;
                final dailyPct = v.yestValue > 0 ? (v.dailyChange / v.yestValue) * 100 : 0.0;
                final valueUSD = portfolio.exchangeRate > 0
                    ? v.value / portfolio.exchangeRate
                    : 0.0;
                final subs = <String, double>{};
                if (v.usValue != 0) subs['미국'] = v.usValue;
                if (v.krValue != 0) subs['한국'] = v.krValue;
                if (v.otherValue != 0) subs['기타'] = v.otherValue;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: AccountCard(
                      account: entry.key,
                      color: getAccountColor(index),
                      valueKRW: v.value,
                      valueUSD: valueUSD,
                      dailyChangeKRW: v.dailyChange,
                      dailyChangePct: dailyPct,
                      profitKRW: profit,
                      profitPct: profitPct,
                      subCategories: subs,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            ...accountMap.entries.indexed.map((e) {
              final (index, entry) = e;
              final v = entry.value;
              final profit = v.value - v.cost;
              final profitPct = v.cost > 0 ? (profit / v.cost) * 100 : 0.0;
              final dailyPct = v.yestValue > 0 ? (v.dailyChange / v.yestValue) * 100 : 0.0;
              final valueUSD = portfolio.exchangeRate > 0
                  ? v.value / portfolio.exchangeRate
                  : 0.0;
              final subs = <String, double>{};
              if (v.usValue != 0) subs['미국'] = v.usValue;
              if (v.krValue != 0) subs['한국'] = v.krValue;
              if (v.otherValue != 0) subs['기타'] = v.otherValue;

              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                child: AccountCard(
                  account: entry.key,
                  color: getAccountColor(index),
                  valueKRW: v.value,
                  valueUSD: valueUSD,
                  dailyChangeKRW: v.dailyChange,
                  dailyChangePct: dailyPct,
                  profitKRW: profit,
                  profitPct: profitPct,
                  subCategories: subs,
                ),
              );
            }),
        ],
      ),
    );
  }
}
