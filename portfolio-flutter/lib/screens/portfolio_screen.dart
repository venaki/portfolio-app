import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../widgets/holding_card.dart';
import '../widgets/segmented_filter.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  String _accountFilter = '전체';
  String _marketFilter = '전체';

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final accounts = ['전체', ...portfolio.settings.accounts];

    var holdings = portfolio.holdings;

    // 필터 적용
    if (_accountFilter != '전체') {
      holdings = holdings.where((h) => h.account == _accountFilter).toList();
    }
    if (_marketFilter != '전체') {
      final marketMap = {'미국': Market.us, '한국 (KRX)': Market.krx, '한국 (KOSDAQ)': Market.kosdaq};
      final targetMarkets = _marketFilter == '한국'
          ? [Market.krx, Market.kosdaq]
          : [marketMap[_marketFilter] ?? Market.us];
      holdings = holdings.where((h) => targetMarkets.contains(h.market)).toList();
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            // Header
            const SizedBox(height: 24),
            const Text(
              '포트폴리오',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // Filter tabs
            SegmentedFilter(
              options: accounts,
              selected: _accountFilter,
              onChanged: (v) => setState(() => _accountFilter = v),
            ),
            const SizedBox(height: 8),
            SegmentedFilter(
              options: const ['전체', '미국', '한국', '기타'],
              selected: _marketFilter,
              onChanged: (v) => setState(() => _marketFilter = v),
            ),
            const SizedBox(height: 24),
            // Holdings
            if (holdings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('보유 종목이 없습니다'),
                ),
              )
            else
              ...holdings.asMap().entries.map((entry) {
                final index = entry.key;
                final h = entry.value;
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: HoldingCard(
                    holding: h,
                    quote: portfolio.quotes[h.ticker],
                    exchangeRate: portfolio.exchangeRate,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
