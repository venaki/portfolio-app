import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../widgets/holding_card.dart';
import '../widgets/asset_card.dart';
import '../engine/calculations.dart';
import '../utils/format.dart';
import '../utils/constants.dart';
import '../widgets/holding_transactions_modal.dart';
import '../widgets/change_row.dart';
import '../providers/filter_provider.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  List<Holding>? _editOrderHoldings;

  void _enterEditMode(List<Holding> holdings) {
    setState(() => _editOrderHoldings = List.from(holdings));
    ref.read(portfolioEditModeProvider.notifier).state = true;
  }

  void _cancelEditMode() {
    setState(() => _editOrderHoldings = null);
    ref.read(portfolioEditModeProvider.notifier).state = false;
  }

  void _saveOrder() {
    if (_editOrderHoldings == null) return;
    final settings = ref.read(portfolioProvider).settings;
    final order = _editOrderHoldings!
        .map((h) => AppSettings.holdingKey(h.ticker, h.account, h.broker))
        .toList();
    ref.read(portfolioProvider.notifier).updateSettings(
          settings.copyWith(holdingOrder: order),
        );
    setState(() => _editOrderHoldings = null);
    ref.read(portfolioEditModeProvider.notifier).state = false;
  }

  void _reorderHoldings(int oldIndex, int newIndex) {
    if (_editOrderHoldings == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editOrderHoldings!.removeAt(oldIndex);
      _editOrderHoldings!.insert(newIndex, item);
    });
  }

  /// holdingOrder에 따라 holdings 정렬
  List<Holding> _sortHoldings(List<Holding> holdings, List<String> holdingOrder) {
    if (holdingOrder.isEmpty) return holdings;
    return List.from(holdings)
      ..sort((a, b) {
        final aKey = AppSettings.holdingKey(a.ticker, a.account, a.broker);
        final bKey = AppSettings.holdingKey(b.ticker, b.account, b.broker);
        final ai = holdingOrder.indexOf(aKey);
        final bi = holdingOrder.indexOf(bKey);
        final aIdx = ai == -1 ? holdingOrder.length : ai;
        final bIdx = bi == -1 ? holdingOrder.length : bi;
        return aIdx.compareTo(bIdx);
      });
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final isEditMode = ref.watch(portfolioEditModeProvider);
    final accentColor = Theme.of(context).colorScheme.primary;
    final accounts = ['전체', ...portfolio.settings.accounts];
    final _accountFilter = ref.watch(portfolioAccountFilter);
    final _marketFilter = ref.watch(portfolioMarketFilter);

    var holdings = portfolio.holdings;
    var consolidatedAssets = portfolio.consolidatedOtherAssets;
    final showOtherOnly = _marketFilter == '기타';
    final showStocksOnly = _marketFilter == '미국' || _marketFilter == '한국';

    // 계정 필터
    if (_accountFilter != '전체') {
      holdings = holdings.where((h) => h.account == ref.watch(portfolioAccountFilter)).toList();
      consolidatedAssets = consolidatedAssets.where((a) => a.account == ref.watch(portfolioAccountFilter)).toList();
    }
    // 시장 필터
    if (_marketFilter == '미국') {
      holdings = holdings.where((h) => h.market == Market.us).toList();
    } else if (_marketFilter == '한국') {
      holdings = holdings.where((h) => h.market == Market.krx || h.market == Market.kosdaq).toList();
    }

    // 정상 모드: holdingOrder 순서 적용
    if (!isEditMode) {
      holdings = _sortHoldings(holdings, portfolio.settings.holdingOrder);
    }

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      bottomNavigationBar: isEditMode
          ? Container(
              padding: const EdgeInsets.fromLTRB(21, 12, 21, 21),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _cancelEditMode,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _saveOrder,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 24),
          children: [
            // Account filter (좌) + Market filter (우)
            if (!isEditMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _buildAccountFilter(accounts)),
                  _buildMarketFilter(),
                ],
              ),
            if (!isEditMode)
              const SizedBox(height: 16),
            // 합계
            if (!isEditMode && (holdings.isNotEmpty || consolidatedAssets.isNotEmpty))
              _buildSummary(holdings, consolidatedAssets, portfolio),

            // Content
            if (isEditMode)
              _buildEditList(portfolio)
            else if (isWide)
              _buildPCTable(holdings, consolidatedAssets, portfolio, showOtherOnly, showStocksOnly)
            else
              _buildMobileCards(holdings, consolidatedAssets, portfolio, showOtherOnly, showStocksOnly),

            // 편집 버튼 (정상 모드에서만, 주식이 있을 때만)
            if (!isEditMode && holdings.isNotEmpty && !showOtherOnly)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _enterEditMode(holdings),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert, size: 16, color: Color(0xFF888888)),
                          SizedBox(width: 6),
                          Text(
                            '순서 편집',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditList(dynamic portfolio) {
    final items = _editOrderHoldings ?? [];
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 2,
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      onReorder: _reorderHoldings,
      itemBuilder: (context, index) {
        final h = items[index];
        final quote = portfolio.quotes[h.ticker] as StockQuote?;
        final price = quote?.price ?? 0;
        final isKR = h.market == Market.krx || h.market == Market.kosdaq;
        final displayName = isKR && quote != null && quote.name.isNotEmpty
            ? quote.name
            : h.ticker;
        final totalValueKRW = calcTotalValueKRW(h, price, portfolio.exchangeRate);

        return Container(
          key: ValueKey(AppSettings.holdingKey(h.ticker, h.account, h.broker)),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.drag_handle, size: 20, color: Color(0xFFCCCCCC)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _marketBadge(h.account),
                      ],
                    ),
                    if (!isKR || (quote != null && quote.name.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isKR ? h.ticker : (quote?.name ?? ''),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatKRW(totalValueKRW),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountFilter(List<String> accounts) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: accounts.map((account) {
        final isSelected = account == ref.watch(portfolioAccountFilter);
        return GestureDetector(
          onTap: () => ref.read(portfolioAccountFilter.notifier).state = account,
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

  Widget _buildSummary(List<Holding> holdings, List<ConsolidatedAsset> consolidatedAssets, dynamic portfolio) {
    double totalValue = 0;
    double totalCost = 0;
    for (final h in holdings) {
      final quote = portfolio.quotes[h.ticker] as StockQuote?;
      final price = quote?.price ?? 0;
      totalValue += calcTotalValueKRW(h, price, portfolio.exchangeRate);
      totalCost += calcCostKRW(h);
    }
    for (final ca in consolidatedAssets) {
      // 대출: 양수 totalValue = 빚이므로 순자산에서 차감
      final raw = ca.category == AssetCategory.loan ? -ca.totalValue.abs() : ca.totalValue;
      final v = ca.currency == Currency.krw ? raw : raw * portfolio.exchangeRate;
      totalValue += v;
      totalCost += v;
    }
    final profit = totalValue - totalCost;
    final profitPct = totalCost > 0 ? (profit / totalCost) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        children: [
          // Row 1: 합계 + 평가금액
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('합계',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              Text(formatKRW(totalValue),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: 원금 + 수익
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('원금 ', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  Text(formatKRW(totalCost),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
                ],
              ),
              ChangeRow(
                changeKRW: profit,
                changePct: profitPct,
                label: '',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketFilter() {
    const options = ['전체', '미국', '한국', '기타'];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: options.map((option) {
        final isSelected = option == ref.watch(portfolioMarketFilter);
        return GestureDetector(
          onTap: () => ref.read(portfolioMarketFilter.notifier).state = option,
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
    ),
    );
  }

  // ─── PC: Table layout ────────────────────────────────────────────

  Widget _buildPCTable(
    List<Holding> holdings,
    List<ConsolidatedAsset> consolidatedAssets,
    dynamic portfolio,
    bool showOtherOnly,
    bool showStocksOnly,
  ) {
    final hasContent = (!showOtherOnly && holdings.isNotEmpty) ||
        (!showStocksOnly && consolidatedAssets.isNotEmpty);

    if (!hasContent) return _buildEmptyState();

    final accountOrder = portfolio.settings.accounts as List<String>;
    final rows = <Widget>[
      _buildTableHeader(),
      const Divider(height: 1, color: Color(0xFFE5E5E5)),
    ];

    for (final account in accountOrder) {
      final accHoldings = showOtherOnly ? <Holding>[] : holdings.where((h) => h.account == account).toList();
      final accAssets = showStocksOnly ? <ConsolidatedAsset>[] : consolidatedAssets.where((a) => a.account == account).toList();
      if (accHoldings.isEmpty && accAssets.isEmpty) continue;

      rows.add(_buildAccountDivider(account));
      for (final h in accHoldings) {
        rows.add(_buildTableRow(h, portfolio.quotes[h.ticker], portfolio.exchangeRate));
      }
      for (final a in accAssets) {
        rows.add(_buildOtherAssetTableRow(a));
      }
    }

    return Column(children: rows);
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

    return Column(
      children: [
        GestureDetector(
          onTap: () => showHoldingTransactionsDialog(
            context,
            ticker: holding.ticker,
            displayName: displayTicker,
            account: holding.account,
            broker: holding.broker,
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
                        _marketBadge(holding.account),
                        const SizedBox(width: 4),
                        _marketBadge(isKR ? '한국' : '미국'),
                        if (holding.broker.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _marketBadge(holding.broker),
                        ],
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

  Widget _buildOtherAssetTableRow(ConsolidatedAsset asset) {
    final isLoan = asset.category == AssetCategory.loan;
    final isUSD = asset.currency == Currency.usd;
    final displayValue = isLoan ? -asset.totalValue.abs() : asset.totalValue;

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
    List<ConsolidatedAsset> consolidatedAssets,
    dynamic portfolio,
    bool showOtherOnly,
    bool showStocksOnly,
  ) {
    final hasContent = (!showOtherOnly && holdings.isNotEmpty) ||
        (!showStocksOnly && consolidatedAssets.isNotEmpty);

    if (!hasContent) return _buildEmptyState();

    final accountOrder = portfolio.settings.accounts as List<String>;
    final widgets = <Widget>[];

    for (final account in accountOrder) {
      final accHoldings = showOtherOnly ? <Holding>[] : holdings.where((h) => h.account == account).toList();
      final accAssets = showStocksOnly ? <ConsolidatedAsset>[] : consolidatedAssets.where((a) => a.account == account).toList();
      if (accHoldings.isEmpty && accAssets.isEmpty) continue;

      widgets.add(_buildAccountDivider(account));
      for (final h in accHoldings) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: HoldingCard(
            holding: h,
            quote: portfolio.quotes[h.ticker],
            exchangeRate: portfolio.exchangeRate,
            onTap: () {
              final isKR = h.market == Market.krx || h.market == Market.kosdaq;
              final q = portfolio.quotes[h.ticker];
              final name = isKR && q != null && q.name.isNotEmpty ? q.name : h.ticker;
              showHoldingTransactionsDialog(context, ticker: h.ticker, displayName: name, account: h.account, broker: h.broker);
            },
          ),
        ));
      }
      for (final a in accAssets) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ConsolidatedAssetCard(asset: a),
        ));
      }
    }

    return Column(children: widgets);
  }

  // ─── Shared widgets ──────────────────────────────────────────────

  Widget _buildAccountDivider(String account) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        account,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

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
