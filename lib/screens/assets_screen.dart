import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import '../utils/format.dart';
import '../widgets/asset_card.dart';
import '../providers/filter_provider.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final _accountFilter = ref.watch(assetsAccountFilter);

    if (portfolio.isLoading && portfolio.otherAssets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = ['전체', ...portfolio.settings.accounts];

    var consolidated = portfolio.consolidatedOtherAssets;
    if (_accountFilter != '전체') {
      consolidated = consolidated.where((a) => a.account == _accountFilter).toList();
    }

    final total = consolidated.fold<double>(0.0, (sum, a) {
      final raw = a.category == AssetCategory.loan ? -a.totalValue.abs() : a.totalValue;
      return sum + (a.currency == Currency.krw ? raw : raw * portfolio.exchangeRate);
    });

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 80),
        children: [
          // Filter: Account (pill style)
          _buildAccountFilter(accounts),
          const SizedBox(height: 24),

          // Total row
          if (consolidated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('합계',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  Text(formatKRW(total),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                ],
              ),
            ),

          if (consolidated.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('등록된 자산이 없습니다',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ),
            ),

          ..._buildGroupedByAccount(consolidated, portfolio.settings.accounts),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedByAccount(List<ConsolidatedAsset> assets, List<String> accountOrder) {
    final widgets = <Widget>[];
    for (final account in accountOrder) {
      final accAssets = assets.where((a) => a.account == account).toList();
      if (accAssets.isEmpty) continue;

      widgets.add(_buildAccountDivider(account));
      for (final a in accAssets) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ConsolidatedAssetCard(asset: a),
        ));
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

  Widget _buildAccountFilter(List<String> accounts) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: accounts.map((account) {
        final isSelected = account == ref.watch(assetsAccountFilter);
        return GestureDetector(
          onTap: () => ref.read(assetsAccountFilter.notifier).state = account,
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
}
