import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
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

          ..._buildGroupedAssets(filtered),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedAssets(List<OtherAsset> assets) {
    // 날짜순 정렬 (최신 먼저)
    final sorted = List<OtherAsset>.from(assets)
      ..sort((a, b) => b.date.compareTo(a.date));

    final grouped = <String, List<OtherAsset>>{};
    for (final a in sorted) {
      final key = _monthKey(a.date);
      (grouped[key] ??= []).add(a);
    }

    return grouped.entries.expand((entry) => [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(
          entry.key,
          style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFF888888)),
        ),
      ),
      ...entry.value.map(
        (asset) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AssetCard(
            asset: asset,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]).toList();
  }

  String _monthKey(String date) {
    if (date.length < 7) return date;
    final year = date.substring(0, 4);
    final month = date.substring(5, 7);
    return '$year년 $month월';
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
