import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../engine/portfolio_valuation.dart';
import '../widgets/segmented_filter.dart';
import 'dashboard/overview_view.dart';
import 'dashboard/trend_view.dart';
import 'dashboard/allocation_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final tab = ref.watch(dashboardAnalysisTabProvider);
    if (state.isLoading &&
        state.holdings.isEmpty &&
        state.otherAssets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final valuation = evaluatePortfolio(
      holdings: state.holdings,
      otherAssets: state.consolidatedOtherAssets,
      quotes: state.quotes,
      exchangeRate: state.exchangeRate,
    );
    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;
    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Row(
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
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: state.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () => ref
                              .read(portfolioProvider.notifier)
                              .refreshPrices(force: true),
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF888888),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          tooltip: '새로고침',
                        ),
                ),
              ],
            ),
          ),
          if (tab != '추이' && valuation.issues.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '일부 시세를 확인하지 못했습니다. 확인된 금액 또는 이전 시세를 표시합니다.',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              ),
            ),
          if (tab == '추이')
            DashboardTrendView(portfolio: state)
          else if (tab == '비중')
            DashboardAllocationView(valuation: valuation, portfolio: state)
          else
            DashboardOverviewView(portfolio: state, valuation: valuation),
        ],
      ),
    );
  }
}
