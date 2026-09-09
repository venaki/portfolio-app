import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../engine/portfolio_valuation.dart';
import '../providers/portfolio_provider.dart';
import '../utils/format.dart';
import '../widgets/asset_card.dart';
import '../providers/filter_provider.dart';
import '../widgets/asset_transactions_modal.dart';
import '../widgets/add_asset_modal.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  bool _showUSD = false;

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);

    if (portfolio.isLoading && portfolio.otherAssets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = <String>{
      '전체',
      ...portfolio.settings.accounts,
      ...portfolio.holdings.map((h) => h.account),
      ...portfolio.otherAssets.map((a) => a.account),
    }.toList();

    final selectedAccount = ref.watch(assetsAccountFilter);
    final accountFilter = accounts.contains(selectedAccount)
        ? selectedAccount
        : '전체';

    var consolidated = portfolio.consolidatedOtherAssets;
    if (accountFilter != '전체') {
      consolidated = consolidated
          .where((a) => a.account == accountFilter)
          .toList();
    }

    final valuation = evaluatePortfolio(
      holdings: [],
      otherAssets: consolidated,
      quotes: portfolio.quotes,
      exchangeRate: portfolio.exchangeRate,
    );
    final total = valuation.total.valueKRW;

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: '자산 내역 추가',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => showAddAssetDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 80),
        children: [
          // Filter: Account (pill style)
          _buildAccountFilter(accounts, accountFilter),
          const SizedBox(height: 24),

          // Total row
          if (consolidated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    valuation.isComplete ? '합계' : '확인된 평가금액',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showUSD = !_showUSD),
                    child: Text(
                      _showUSD && portfolio.exchangeRate > 0
                          ? formatUSD(total / portfolio.exchangeRate)
                          : formatKRW(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (consolidated.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  '등록된 자산이 없습니다',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ),
            ),

          ..._buildGroupedByAccount(consolidated, portfolio.settings.accounts),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedByAccount(
    List<ConsolidatedAsset> assets,
    List<String> accountOrder,
  ) {
    final widgets = <Widget>[];
    for (final account in {...accountOrder, ...assets.map((a) => a.account)}) {
      final accAssets = assets.where((a) => a.account == account).toList();
      if (accAssets.isEmpty) continue;

      widgets.add(_buildAccountDivider(account));
      for (final a in accAssets) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConsolidatedAssetCard(
              asset: a,
              onTap: () => showAssetTransactionsDialog(context, a),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildAccountDivider(String account) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          account,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF888888),
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountFilter(List<String> accounts, String selected) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: accounts.map((account) {
        final isSelected = account == selected;
        return GestureDetector(
          onTap: () => ref.read(assetsAccountFilter.notifier).state = account,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFE5E5E5)),
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
}
