import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/portfolio_provider.dart';
import '../../engine/portfolio_valuation.dart';
import '../../models/transaction.dart';
import '../../widgets/segmented_filter.dart';
import '../../widgets/holding_transactions_modal.dart';
import '../../widgets/asset_transactions_modal.dart';
import '../../utils/format.dart';

class DashboardOverviewView extends ConsumerWidget {
  const DashboardOverviewView({
    super.key,
    required this.portfolio,
    required this.valuation,
  });
  final PortfolioState portfolio;
  final PortfolioValuation valuation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = valuation.total;
    final mode = ref.watch(dashboardViewModeProvider);
    final accounts = {
      ...portfolio.settings.accounts,
      ...valuation.byAccount.keys,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valuation.isComplete ? '총 순자산' : '확인된 평가금액 · 일부 미평가',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatKRW(total.valueKRW),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (portfolio.exchangeRate.isFinite &&
                        portfolio.exchangeRate > 0)
                      Text(formatUSD(total.valueKRW / portfolio.exchangeRate)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  valuation.isDailyComplete
                      ? '보유자산 주가 변동 ${formatKRW(total.dailyChangeKRW)} (${formatPercent(total.dailyChangePct)})'
                      : '일간 주가 변동: 시세 확인 필요',
                ),
                const Divider(height: 24),
                Text('현재 보유 원가 ${formatKRW(total.costKRW)}'),
                Text(
                  valuation.isComplete
                      ? '평가손익 ${formatKRW(total.profitKRW)} (${formatPercent(total.profitPct)})'
                      : '평가손익: 시세 확인 필요',
                ),
                const SizedBox(height: 8),
                const Text(
                  '평가손익은 현재 보유자산 기준이며, 실현손익·수수료·세금은 포함하지 않습니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedFilter(
          options: const ['By Account', 'By Type'],
          selected: mode,
          onChanged: (value) =>
              ref.read(dashboardViewModeProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        if (mode == 'By Account')
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 700 ? 2 : 1;
              final width = (constraints.maxWidth - (count - 1) * 12) / count;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final account in accounts)
                    if (valuation.byAccount.containsKey(account))
                      SizedBox(
                        width: width,
                        child: _AccountSummary(
                          account: account,
                          totals: valuation.byAccount[account]!,
                          complete: valuation.isComplete,
                          dailyComplete: valuation.isDailyComplete,
                        ),
                      ),
                ],
              );
            },
          )
        else ...[
          for (final market in [Market.us, Market.krx])
            _group(context, market == Market.us ? '미국주식' : '한국주식', [
              for (final position in valuation.positions.where(
                (position) =>
                    (position.holding.market == Market.us) ==
                    (market == Market.us),
              ))
                ListTile(
                  title: Text(position.quote?.name ?? position.holding.ticker),
                  subtitle: Text(
                    '${position.holding.account} · ${position.holding.ticker}',
                  ),
                  trailing: Text(
                    position.valueKRW == null
                        ? '미평가'
                        : formatKRW(position.valueKRW!),
                  ),
                  onTap: () => showHoldingTransactionsDialog(
                    context,
                    ticker: position.holding.ticker,
                    displayName:
                        position.quote?.name ?? position.holding.ticker,
                    account: position.holding.account,
                    broker: position.holding.broker,
                    market: position.holding.market,
                    currency: position.holding.currency,
                  ),
                ),
            ]),
          _group(context, '기타자산', [
            for (final value in valuation.assets)
              ListTile(
                title: Text(value.asset.name),
                subtitle: Text(
                  '${value.asset.account} · ${value.asset.categoryLabel}',
                ),
                trailing: Text(
                  value.valueKRW == null ? '미평가' : formatKRW(value.valueKRW!),
                ),
                onTap: () => showAssetTransactionsDialog(context, value.asset),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> rows) =>
      rows.isEmpty
      ? const SizedBox.shrink()
      : Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...rows,
            ],
          ),
        );
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.account,
    required this.totals,
    required this.complete,
    required this.dailyComplete,
  });
  final String account;
  final ValuationTotals totals;
  final bool complete, dailyComplete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            formatKRW(totals.valueKRW),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            dailyComplete
                ? '주가 변동 ${formatKRW(totals.dailyChangeKRW)} (${formatPercent(totals.dailyChangePct)})'
                : '주가 변동: 시세 확인 필요',
          ),
          Text(
            complete
                ? '평가손익 ${formatKRW(totals.profitKRW)} (${formatPercent(totals.profitPct)})'
                : '평가손익: 시세 확인 필요',
          ),
          const Divider(),
          Text('미국 ${formatKRW(totals.usValueKRW)}'),
          Text('한국 ${formatKRW(totals.krValueKRW)}'),
          Text('기타 ${formatKRW(totals.otherValueKRW)}'),
        ],
      ),
    ),
  );
}
