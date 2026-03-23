import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../providers/portfolio_provider.dart';
import '../utils/format.dart';
import '../widgets/segmented_filter.dart';
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

    // 필터 적용
    final filtered = _accountFilter == '전체'
        ? portfolio.otherAssets
        : portfolio.otherAssets
            .where((a) => a.account == _accountFilter)
            .toList();

    // 합계 계산 (대출은 음수)
    final total = filtered.fold<double>(0.0, (sum, a) {
      final value = a.category == AssetCategory.loan && a.value > 0
          ? -a.value
          : a.value;
      return sum + value;
    });

    final isWide = MediaQuery.of(context).size.width >= 768;
    final hPadding = isWide ? 40.0 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '기타 자산',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => showAddAssetDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter: Account
        SegmentedFilter(
          options: accounts,
          selected: _accountFilter,
          onChanged: (v) => setState(() => _accountFilter = v),
        ),
        const SizedBox(height: 24),

        // Total row
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '합계',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                formatKRW(total),
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),

        // Empty state
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                '등록된 자산이 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
          ),

        // Asset cards
        ...filtered.asMap().entries.map((entry) {
          final index = entry.key;
          final asset = entry.value;
          return Column(
            children: [
              if (index > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
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
    );
  }
}
