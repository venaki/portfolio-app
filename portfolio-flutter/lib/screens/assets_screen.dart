import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../providers/portfolio_provider.dart';
import '../utils/format.dart';
import '../widgets/asset_card.dart';
import '../widgets/add_asset_modal.dart';
import '../widgets/edit_asset_modal.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String _accountFilter = '전체';

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final accentColor = Theme.of(context).colorScheme.primary;

    if (portfolio.isLoading && portfolio.otherAssets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = ['전체', ...portfolio.settings.accounts];

    final filtered = _accountFilter == '전체'
        ? portfolio.otherAssets
        : portfolio.otherAssets
            .where((a) => a.account == _accountFilter)
            .toList();

    final total = filtered.fold<double>(0.0, (sum, a) {
      final value = a.category == AssetCategory.loan && a.value > 0
          ? -a.value
          : a.value;
      return sum + value;
    });

    final isWide = MediaQuery.of(context).size.width >= 768;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddAssetDialog(context),
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 80),
        children: [
          // Filter: Account (pill style)
          _buildAccountFilter(accounts),
          const SizedBox(height: 24),

          // Total row
          if (filtered.isNotEmpty)
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

          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('등록된 자산이 없습니다',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ),
            ),

          ...filtered.asMap().entries.map((entry) {
            final index = entry.key;
            final asset = entry.value;
            return Column(
              children: [
                if (index > 0)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: AssetCard(
                    asset: asset,
                    onTap: () => showEditAssetDialog(context, asset),
                  ),
                ),
              ],
            );
          }),
        ],
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
}
