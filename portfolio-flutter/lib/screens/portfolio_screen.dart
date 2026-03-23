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
  bool _filtersExpanded = false;

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

    final isWide = MediaQuery.of(context).size.width >= 768;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: const Text(
                '포트폴리오',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            // Filter tabs
            SegmentedFilter(
              options: accounts,
              selected: _accountFilter,
              onChanged: (v) => setState(() => _accountFilter = v),
            ),
            const SizedBox(height: 8),
            if (_filtersExpanded) ...[
              SegmentedFilter(
                options: const ['전체', '미국', '한국'],
                selected: _marketFilter,
                onChanged: (v) => setState(() => _marketFilter = v),
              ),
              const SizedBox(height: 8),
            ],
            GestureDetector(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _filtersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: const Color(0xFFAAAAAA),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _filtersExpanded ? '필터 접기' : '필터 더보기',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
