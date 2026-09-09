import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/portfolio_provider.dart';
import '../../engine/portfolio_valuation.dart';
import '../../models/other_asset.dart';
import '../../models/transaction.dart';
import '../../widgets/total_asset_card.dart';
import '../../widgets/account_card.dart';
import '../../widgets/type_group_card.dart';
import '../../widgets/segmented_filter.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';

class DashboardOverviewView extends ConsumerWidget {
  const DashboardOverviewView({
    super.key,
    required this.portfolio,
    required this.valuation,
  });
  final PortfolioState portfolio;
  final PortfolioValuation valuation;

  double _usd(double amount) =>
      portfolio.exchangeRate.isFinite && portfolio.exchangeRate > 0
      ? amount / portfolio.exchangeRate
      : double.nan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = valuation.total;
    final mode = ref.watch(dashboardViewModeProvider);
    final isWide = MediaQuery.of(context).size.width >= 1024;
    final accounts = valuation.byAccount.entries.toList()
      ..sort((a, b) {
        final order = portfolio.settings.accounts;
        final ai = order.indexOf(a.key), bi = order.indexOf(b.key);
        return (ai < 0 ? order.length : ai).compareTo(
          bi < 0 ? order.length : bi,
        );
      });
    final updated = portfolio.lastUpdated;
    final accountCards = accounts.indexed.map((entry) {
      final index = entry.$1, value = entry.$2.value;
      return AccountCard(
        account: entry.$2.key,
        color: getAccountColor(index),
        valueKRW: value.valueKRW,
        valueUSD: _usd(value.valueKRW),
        dailyChangeKRW: valuation.isDailyComplete
            ? value.dailyChangeKRW
            : double.nan,
        dailyChangePct: valuation.isDailyComplete
            ? value.dailyChangePct
            : double.nan,
        profitKRW: valuation.isComplete ? value.profitKRW : double.nan,
        profitPct: valuation.isComplete ? value.profitPct : double.nan,
        subCategories: {
          if (value.usValueKRW != 0) '미국': value.usValueKRW,
          if (value.krValueKRW != 0) '한국': value.krValueKRW,
          if (value.otherValueKRW != 0) '기타': value.otherValueKRW,
        },
      );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TotalAssetCard(
          totalValueKRW: total.valueKRW,
          totalValueUSD: _usd(total.valueKRW),
          dailyChangeKRW: valuation.isDailyComplete
              ? total.dailyChangeKRW
              : double.nan,
          dailyChangePct: valuation.isDailyComplete
              ? total.dailyChangePct
              : double.nan,
          totalCostKRW: total.costKRW,
          totalProfitKRW: valuation.isComplete ? total.profitKRW : double.nan,
          totalProfitPct: valuation.isComplete ? total.profitPct : double.nan,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 USD = ${formatKRW(portfolio.exchangeRate)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888),
              ),
            ),
            if (updated != null)
              Text(
                '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')} 업데이트',
                style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 240,
          child: SegmentedFilter(
            options: const ['By Account', 'By Type'],
            selected: mode,
            onChanged: (value) =>
                ref.read(dashboardViewModeProvider.notifier).state = value,
          ),
        ),
        const SizedBox(height: 12),
        if (mode == 'By Account') ...[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: accountCards.indexed
                  .map(
                    (entry) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: entry.$1 == 0 ? 0 : 8),
                        child: entry.$2,
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            ...accountCards.indexed.map(
              (entry) => Padding(
                padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 8),
                child: entry.$2,
              ),
            ),
        ] else
          ..._typeCards(),
      ],
    );
  }

  List<Widget> _typeCards() {
    final us = <String, HoldingRow>{}, kr = <String, HoldingRow>{};
    for (final position in valuation.positions) {
      final h = position.holding;
      final map = h.market == Market.us ? us : kr;
      final key = jsonEncode([h.ticker, h.market.name, h.currency.name]);
      final old = map[key];
      map[key] = HoldingRow(
        name: position.quote?.name ?? h.ticker,
        ticker: h.ticker,
        valueKRW: (old?.valueKRW ?? 0) + (position.valueKRW ?? 0),
        costKRW: (old?.costKRW ?? 0) + position.costKRW,
        dailyChangeKRW:
            (old?.dailyChangeKRW ?? 0) + (position.dailyChangeKRW ?? 0),
        yestValueKRW: (old?.yestValueKRW ?? 0) + (position.yestValueKRW ?? 0),
        shares: (old?.shares ?? 0) + h.shares,
        isComplete:
            (old?.isComplete ?? true) &&
            position.valueKRW != null &&
            position.quote?.isStale != true,
        hasPrice: (old?.hasPrice ?? true) && position.hasPrice,
        isDailyComplete:
            (old?.isDailyComplete ?? true) && position.dailyChangeKRW != null,
      );
    }
    final other = <AssetCategory, List<HoldingRow>>{};
    for (final value in valuation.assets) {
      final asset = value.asset;
      (other[asset.category] ??= []).add(
        HoldingRow(
          name: asset.name,
          ticker: asset.name,
          valueKRW: value.valueKRW ?? 0,
          costKRW: value.valueKRW ?? 0,
          dailyChangeKRW: 0,
          yestValueKRW: value.valueKRW ?? 0,
          hasPrice: value.valueKRW != null,
          isComplete: value.valueKRW != null,
        ),
      );
    }
    final groups = <(String, List<HoldingRow>)>[
      (
        '미국주식',
        us.values.toList()..sort((a, b) => b.valueKRW.compareTo(a.valueKRW)),
      ),
      (
        '한국주식',
        kr.values.toList()..sort((a, b) => b.valueKRW.compareTo(a.valueKRW)),
      ),
      for (final category in AssetCategory.values)
        (
          switch (category) {
            AssetCategory.savings => '예금',
            AssetCategory.bond => '채권',
            AssetCategory.loan => '대출',
            AssetCategory.other => '기타',
          },
          other[category] ?? [],
        ),
    ].where((group) => group.$2.isNotEmpty).toList();
    return groups.indexed
        .map(
          (entry) => Padding(
            padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 8),
            child: TypeGroupCard(title: entry.$2.$1, items: entry.$2.$2),
          ),
        )
        .toList();
  }
}
