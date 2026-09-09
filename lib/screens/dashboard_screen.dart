import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../engine/portfolio_valuation.dart';
import '../widgets/segmented_filter.dart';
import '../utils/format.dart';
import 'dashboard/overview_view.dart';
import 'dashboard/trend_view.dart';
import 'dashboard/allocation_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final tab = ref.watch(dashboardAnalysisTabProvider);
    final valuation = evaluatePortfolio(
      holdings: state.holdings,
      otherAssets: state.consolidatedOtherAssets,
      quotes: state.quotes,
      exchangeRate: state.exchangeRate,
    );
    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedFilter(
                  options: const ['현황', '추이', '비중'],
                  selected: tab,
                  onChanged: (value) =>
                      ref.read(dashboardAnalysisTabProvider.notifier).state =
                          value,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '시세 새로고침',
                onPressed: state.isLoading
                    ? null
                    : () => ref
                          .read(portfolioProvider.notifier)
                          .refreshPrices(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (state.isLoading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (valuation.issues.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '일부 시세를 확인하지 못했습니다. 합계는 확인된 값 또는 이전 시세를 포함합니다.\n${valuation.issues.join('\n')}',
                ),
              ),
            ),
          if (tab == '추이')
            DashboardTrendView(portfolio: state)
          else if (tab == '비중')
            DashboardAllocationView(valuation: valuation)
          else
            DashboardOverviewView(portfolio: state, valuation: valuation),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '1 USD = ${formatKRW(state.exchangeRate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                state.lastUpdated == null
                    ? '아직 동기화하지 않았습니다'
                    : '최근 동기화 ${state.lastUpdated!.toLocal().toString().substring(0, 16)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
