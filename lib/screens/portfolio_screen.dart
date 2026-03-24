import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
import '../widgets/holding_card.dart';
import '../widgets/asset_card.dart';
import '../engine/calculations.dart';
import '../utils/format.dart';
import '../utils/constants.dart';
import '../widgets/holding_transactions_modal.dart';

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
    final accentColor = Theme.of(context).colorScheme.primary;
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
          padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 24),
          children: [
            // Account filter
            _buildAccountFilter(accounts),
            const SizedBox(height: 12),
            // Market filter
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildMarketFilter(),
            ),
            // Content: PC table vs Mobile cards
            if (isWide)
              _buildPCTable(holdings, otherAssets, portfolio, showOtherOnly, showStocksOnly)
            else
              _buildMobileCards(holdings, otherAssets, portfolio, showOtherOnly, showStocksOnly),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountFilter(List<String> accounts) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: accounts.map((account) {
        final isSelected = account == _accountFilter;
        return GestureDetector(
          onTap: () => setState(() => _accountFilter = account),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? null : Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Text(
              account,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xFF888888),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMarketFilter() {
    const options = ['전체', '미국', '한국', '기타'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: options.map((option) {
        final isSelected = option == _marketFilter;
        return GestureDetector(
          onTap: () => setState(() => _marketFilter = option),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 2,
                  width: 20,
                  color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── PC: Table layout ────────────────────────────────────────────

  Widget _buildPCTable(
    List<Holding> holdings,
    List<OtherAsset> otherAssets,
    dynamic portfolio,
    bool showOtherOnly,
    bool showStocksOnly,
  ) {
    final hasContent = (!showOtherOnly && holdings.isNotEmpty) ||
        (!showStocksOnly && otherAssets.isNotEmpty);

    if (!hasContent) return _buildEmptyState();

    return Column(
      children: [
        // Table header
        _buildTableHeader(),
        const Divider(height: 1, color: Color(0xFFE5E5E5)),
        // Holdings rows
        if (!showOtherOnly)
          ...holdings.map((h) => _buildTableRow(
                h, portfolio.quotes[h.ticker], portfolio.exchangeRate)),
        // Other assets rows
        if (!showStocksOnly && otherAssets.isNotEmpty)
          ...otherAssets.map((a) => _buildOtherAssetTableRow(a)),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text('종목',
                style: _headerStyle()),
          ),
          Expanded(child: Text('현재가', style: _headerStyle(), textAlign: TextAlign.right)),
          Expanded(child: Text('수익', style: _headerStyle(), textAlign: TextAlign.right)),
          Expanded(child: Text('평단가', style: _headerStyle(), textAlign: TextAlign.right)),
          SizedBox(width: 80, child: Text('수량', style: _headerStyle(), textAlign: TextAlign.right)),
          Expanded(child: Text('평가금액', style: _headerStyle(), textAlign: TextAlign.right)),
          SizedBox(width: 80, child: Text('매입환율', style: _headerStyle(), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF888888),
      );

  Widget _buildTableRow(Holding holding, StockQuote? quote, double exchangeRate) {
    final price = quote?.price ?? 0;
    final changePct = quote?.changePct ?? 0;
    final isKRW = holding.currency == Currency.krw;
    final isKR = holding.market == Market.krx || holding.market == Market.kosdaq;
    final hasQuote = quote != null && price > 0;

    final totalValueKRW = calcTotalValueKRW(holding, price, exchangeRate);
    final costKRW = calcCostKRW(holding);
    final profitKRW = calcProfitKRW(holding, price, exchangeRate);
    final profitPct = calcProfitPercentKRW(holding, price, exchangeRate);

    final dailyColor = changePct >= 0 ? positiveColor : negativeColor;
    final profitColor = profitKRW >= 0 ? positiveColor : negativeColor;

    String fmtPrice(double v) => isKRW ? formatKRW(v) : formatUSD(v);

    final displayTicker = isKR && quote?.name != null && quote!.name.isNotEmpty
        ? quote.name
        : holding.ticker;
    final displayName = isKR ? holding.ticker : (quote?.name ?? '');

    final marketLabel = isKR ? '한국' : '미국';

    return Column(
      children: [
        GestureDetector(
          onTap: () => showHoldingTransactionsDialog(
            context,
            ticker: holding.ticker,
            displayName: displayTicker,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // 종목 column
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayTicker,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _marketBadge(marketLabel),
                      ],
                    ),
                    if (displayName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          displayName,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // 현재가
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasQuote ? fmtPrice(price) : '-',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                    ),
                    if (hasQuote)
                      Text(
                        formatPercent(changePct),
                        style: TextStyle(fontSize: 11, color: dailyColor),
                      ),
                  ],
                ),
              ),
              // 수익
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasQuote ? '${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}' : '-',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: hasQuote ? profitColor : const Color(0xFF1A1A1A)),
                    ),
                    if (hasQuote)
                      Text(
                        formatPercent(profitPct),
                        style: TextStyle(fontSize: 11, color: profitColor),
                      ),
                  ],
                ),
              ),
              // 평단가
              Expanded(
                child: Text(
                  fmtPrice(holding.avgCost),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  textAlign: TextAlign.right,
                ),
              ),
              // 수량
              SizedBox(
                width: 80,
                child: Text(
                  formatShares(holding.shares),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  textAlign: TextAlign.right,
                ),
              ),
              // 평가금액
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasQuote ? formatKRW(totalValueKRW) : '-',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                    ),
                    if (hasQuote)
                      Text(
                        formatKRW(costKRW),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                      ),
                  ],
                ),
              ),
              // 매입환율
              SizedBox(
                width: 80,
                child: Text(
                  !isKRW ? formatKRW(holding.avgExchangeRate) : '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
      ],
    );
  }

  Widget _buildOtherAssetTableRow(OtherAsset asset) {
    final isLoan = asset.category == AssetCategory.loan;
    final isUSD = asset.currency == Currency.usd;
    final displayValue = isLoan && asset.value > 0 ? -asset.value : asset.value;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // 종목 column
              SizedBox(
                width: 180,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        asset.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _categoryBadge(asset.categoryLabel),
                  ],
                ),
              ),
              // 현재가 - empty
              Expanded(child: Text('-', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)), textAlign: TextAlign.right)),
              // 수익 - empty
              Expanded(child: Text('-', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)), textAlign: TextAlign.right)),
              // 평단가 - empty
              Expanded(child: Text('-', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)), textAlign: TextAlign.right)),
              // 수량 - empty
              SizedBox(width: 80, child: Text('-', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)), textAlign: TextAlign.right)),
              // 평가금액 - shows value
              Expanded(
                child: Text(
                  isUSD ? formatUSD(displayValue) : formatKRW(displayValue),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isLoan ? negativeColor : const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              // 매입환율 - empty
              SizedBox(width: 80, child: Text('-', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)), textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
      ],
    );
  }

  // ─── Mobile: Card layout ─────────────────────────────────────────

  Widget _buildMobileCards(
    List<Holding> holdings,
    List<OtherAsset> otherAssets,
    dynamic portfolio,
    bool showOtherOnly,
    bool showStocksOnly,
  ) {
    final hasContent = (!showOtherOnly && holdings.isNotEmpty) ||
        (!showStocksOnly && otherAssets.isNotEmpty);

    if (!hasContent) return _buildEmptyState();

    return Column(
      children: [
        if (!showOtherOnly)
          ...holdings.asMap().entries.map((entry) {
            final index = entry.key;
            final h = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: HoldingCard(
                holding: h,
                quote: portfolio.quotes[h.ticker],
                exchangeRate: portfolio.exchangeRate,
                onTap: () {
                  final isKR = h.market == Market.krx || h.market == Market.kosdaq;
                  final q = portfolio.quotes[h.ticker];
                  final name = isKR && q != null && q.name.isNotEmpty ? q.name : h.ticker;
                  showHoldingTransactionsDialog(context, ticker: h.ticker, displayName: name);
                },
              ),
            );
          }),
        if (!showStocksOnly && otherAssets.isNotEmpty) ...[
          if (holdings.isNotEmpty && !showOtherOnly)
            const SizedBox(height: 8),
          ...otherAssets.asMap().entries.map((entry) {
            final index = entry.key;
            final a = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: index == 0 && (showOtherOnly || holdings.isEmpty) ? 0 : 8),
              child: AssetCard(asset: a),
            );
          }),
        ],
      ],
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────

  Widget _marketBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _categoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          '보유 자산이 없습니다',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
      ),
    );
  }
}
