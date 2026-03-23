import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
import '../widgets/holding_card.dart';
import '../widgets/asset_card.dart';
import '../widgets/segmented_filter.dart';
import '../widgets/edit_asset_modal.dart';

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
    var otherAssets = portfolio.otherAssets;
    final showOtherOnly = _marketFilter == '기타';
    final showStocksOnly = _marketFilter == '미국' || _marketFilter == '한국';

    // 계정 필터
    if (_accountFilter != '전체') {
      holdings = holdings.where((h) => h.account == _accountFilter).toList();
      otherAssets = otherAssets.where((a) => a.account == _accountFilter).toList();
    }
    // 시장 필터
    if (_marketFilter == '미국') {
      holdings = holdings.where((h) => h.market == Market.us).toList();
    } else if (_marketFilter == '한국') {
      holdings = holdings.where((h) => h.market == Market.krx || h.market == Market.kosdaq).toList();
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
                options: const ['전체', '미국', '한국', '기타'],
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
            // Holdings (주식)
            if (!showOtherOnly) ...[
              if (holdings.isNotEmpty)
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

            // 기타자산
            if (!showStocksOnly && otherAssets.isNotEmpty) ...[
              if (holdings.isNotEmpty && !showOtherOnly)
                const SizedBox(height: 8),
              ...otherAssets.asMap().entries.map((entry) {
                final index = entry.key;
                final a = entry.value;
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 && (showOtherOnly || holdings.isEmpty) ? 0 : 8),
                  child: AssetCard(
                    asset: a,
                    onTap: () => showEditAssetDialog(context, a),
                  ),
                );
              }),
            ],

            // 빈 상태
            if ((showOtherOnly && otherAssets.isEmpty) ||
                (showStocksOnly && holdings.isEmpty) ||
                (!showOtherOnly && !showStocksOnly && holdings.isEmpty && otherAssets.isEmpty))
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('보유 자산이 없습니다'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
