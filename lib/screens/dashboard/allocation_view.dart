import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../engine/portfolio_valuation.dart';
import '../../models/other_asset.dart';
import '../../models/transaction.dart';
import '../../providers/portfolio_provider.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../widgets/segmented_filter.dart';

class DashboardAllocationView extends ConsumerStatefulWidget {
  const DashboardAllocationView({
    super.key,
    required this.valuation,
    required this.portfolio,
  });
  final PortfolioValuation valuation;
  final PortfolioState portfolio;
  @override
  ConsumerState<DashboardAllocationView> createState() =>
      _DashboardAllocationViewState();
}

class _DashboardAllocationViewState
    extends ConsumerState<DashboardAllocationView> {
  int _allocationSelectedIndex = 0;
  @override
  Widget build(BuildContext context) => _buildAllocationView(
    portfolio: widget.portfolio,
    mode: ref.watch(dashboardAllocationModeProvider),
    isWide: MediaQuery.of(context).size.width >= 1024,
  );
  Widget _buildAllocationView({
    required PortfolioState portfolio,
    required String mode,
    required bool isWide,
  }) {
    final result = _buildAllocationData(portfolio, mode);
    final items = result.items;
    final liabilities = result.liabilities;
    final total = items.fold<double>(0, (sum, item) => sum + item.valueKRW);
    final liabilityTotal = liabilities.fold<double>(
      0,
      (sum, item) => sum + item.valueKRW,
    );
    final netAssetTotal = total - liabilityTotal;

    if (_allocationSelectedIndex >= items.length) {
      _allocationSelectedIndex = 0;
    }

    if (items.isEmpty || total <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AllocationSummary(
            assetTotal: total,
            liabilityTotal: liabilityTotal,
            netAssetTotal: netAssetTotal,
          ),
          const SizedBox(height: 12),
          _buildComingSoonView(
            icon: Icons.donut_large,
            title: '비중',
            description: '비중을 계산할 수 있는 양수 자산이 아직 없습니다.',
          ),
          if (liabilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LiabilitySection(items: liabilities),
          ],
        ],
      );
    }

    final selected = items[_allocationSelectedIndex];
    final selectedPercent = selected.valueKRW / total * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: isWide ? 320 : double.infinity,
          child: SegmentedFilter(
            options: const ['종목별', '유형별', '계좌별'],
            selected: mode,
            onChanged: (v) {
              setState(() => _allocationSelectedIndex = 0);
              ref.read(dashboardAllocationModeProvider.notifier).state = v;
            },
          ),
        ),
        const SizedBox(height: 12),
        _AllocationSummary(
          assetTotal: total,
          liabilityTotal: liabilityTotal,
          netAssetTotal: netAssetTotal,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: selected.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (selected.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selected.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _formatAllocationPercent(selectedPercent),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '평가액 ${formatKRW(selected.valueKRW)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: isWide ? 320 : 260,
                  height: isWide ? 320 : 260,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: isWide ? 82 : 66,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          if (!event.isInterestedForInteractions ||
                              index == null ||
                              index < 0 ||
                              index >= items.length) {
                            return;
                          }
                          setState(() => _allocationSelectedIndex = index);
                        },
                      ),
                      sections: items.indexed.map((entry) {
                        final (index, item) = entry;
                        final selected = index == _allocationSelectedIndex;
                        final percent = item.valueKRW / total * 100;
                        return PieChartSectionData(
                          value: item.valueKRW,
                          color: item.color,
                          title: percent >= 7
                              ? '${percent.toStringAsFixed(0)}%'
                              : '',
                          radius: selected ? 48 : 42,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Column(
            children: items.indexed.map((entry) {
              final (index, item) = entry;
              final percent = item.valueKRW / total * 100;
              return _AllocationRow(
                item: item,
                percent: percent,
                selected: index == _allocationSelectedIndex,
                onTap: () => setState(() => _allocationSelectedIndex = index),
              );
            }).toList(),
          ),
        ),
        if (liabilities.isNotEmpty) ...[
          const SizedBox(height: 16),
          _LiabilitySection(items: liabilities),
        ],
      ],
    );
  }

  _AllocationResult _buildAllocationData(
    PortfolioState portfolio,
    String mode,
  ) {
    final positive = <String, _AllocationItem>{};
    final liabilities = <String, _AllocationItem>{};

    void addPositive(
      String key,
      String label,
      double value,
      Color color, {
      String? subtitle,
    }) {
      if (value <= 0) return;
      final existing = positive[key];
      positive[key] = existing == null
          ? _AllocationItem(
              label: label,
              valueKRW: value,
              color: color,
              subtitle: subtitle,
            )
          : existing.copyWith(valueKRW: existing.valueKRW + value);
    }

    void addLiability(
      String key,
      String label,
      double value,
      Color color, {
      String? subtitle,
    }) {
      if (value >= 0) return;
      final existing = liabilities[key];
      liabilities[key] = existing == null
          ? _AllocationItem(
              label: label,
              valueKRW: value.abs(),
              color: color,
              subtitle: subtitle,
            )
          : existing.copyWith(valueKRW: existing.valueKRW + value.abs());
    }

    for (final position in widget.valuation.positions) {
      final h = position.holding;
      final quote = position.quote;
      final value = position.valueKRW;
      if (value == null || !value.isFinite) continue;
      final isKorean = h.market == Market.krx || h.market == Market.kosdaq;
      final typeLabel = h.market == Market.us ? '미국주식' : '한국주식';

      switch (mode) {
        case '유형별':
          addPositive(
            'type:$typeLabel',
            typeLabel,
            value,
            isKorean ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          );
          break;
        case '계좌별':
          addPositive(
            'account:${h.account}',
            h.account,
            value,
            getAccountColor(
              portfolio.settings.accounts.indexOf(h.account).clamp(0, 1000000),
            ),
          );
          break;
        default:
          addPositive(
            jsonEncode(['ticker', h.ticker, h.market.name, h.currency.name]),
            h.ticker,
            value,
            _allocationColor(positive.length),
            subtitle: quote?.name,
          );
      }
    }

    for (final assetValue in widget.valuation.assets) {
      final ca = assetValue.asset;
      final value = assetValue.valueKRW;
      if (value == null || !value.isFinite) continue;
      final typeLabel = ca.categoryLabel;

      switch (mode) {
        case '유형별':
          if (value < 0) {
            addLiability(
              'type:$typeLabel',
              typeLabel,
              value,
              const Color(0xFFEF4444),
            );
          } else {
            addPositive(
              'type:$typeLabel',
              typeLabel,
              value,
              _assetCategoryColor(ca.category),
            );
          }
          break;
        case '계좌별':
          final accountIndex = portfolio.settings.accounts.indexOf(ca.account);
          final color = getAccountColor(
            accountIndex < 0 ? positive.length : accountIndex,
          );
          if (value < 0) {
            addLiability('account:${ca.account}', ca.account, value, color);
          } else {
            addPositive('account:${ca.account}', ca.account, value, color);
          }
          break;
        default:
          if (value < 0) {
            addLiability(
              ca.key,
              ca.name,
              value,
              const Color(0xFFEF4444),
              subtitle: ca.account,
            );
          } else {
            addPositive(
              ca.key,
              ca.name,
              value,
              _allocationColor(positive.length),
              subtitle: ca.account,
            );
          }
      }
    }

    final items = positive.values.toList()
      ..sort((a, b) => b.valueKRW.compareTo(a.valueKRW));
    final liabilityItems = liabilities.values.toList()
      ..sort((a, b) => b.valueKRW.compareTo(a.valueKRW));
    return _AllocationResult(items: items, liabilities: liabilityItems);
  }

  Color _allocationColor(int index) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF0D9488),
      Color(0xFF7C3AED),
      Color(0xFFE11D48),
      Color(0xFFF59E0B),
      Color(0xFF16A34A),
      Color(0xFF0891B2),
      Color(0xFFDB2777),
      Color(0xFF64748B),
    ];
    return colors[index % colors.length];
  }

  Color _assetCategoryColor(AssetCategory category) {
    switch (category) {
      case AssetCategory.savings:
        return const Color(0xFF0D9488);
      case AssetCategory.bond:
        return const Color(0xFFF59E0B);
      case AssetCategory.loan:
        return const Color(0xFFEF4444);
      case AssetCategory.other:
        return const Color(0xFF7C3AED);
    }
  }

  String _formatAllocationPercent(double value) =>
      '${value.toStringAsFixed(value >= 10 ? 1 : 2)}%';

  Widget _buildComingSoonView({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF888888)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  final _AllocationItem item;
  final double percent;
  final bool selected;
  final VoidCallback onTap;

  const _AllocationRow({
    required this.item,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: selected ? const Color(0xFFF5F7FA) : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${percent.toStringAsFixed(percent >= 10 ? 1 : 2)}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  formatKRW(item.valueKRW),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationSummary extends StatelessWidget {
  final double assetTotal;
  final double liabilityTotal;
  final double netAssetTotal;

  const _AllocationSummary({
    required this.assetTotal,
    required this.liabilityTotal,
    required this.netAssetTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          _SummaryLine(
            label: '자산 합계',
            value: formatKRW(assetTotal),
            valueColor: const Color(0xFF1A1A1A),
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: '부채',
            value: liabilityTotal > 0
                ? '-${formatKRW(liabilityTotal)}'
                : formatKRW(0),
            valueColor: const Color(0xFFEF4444),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFEDEDED)),
          ),
          _SummaryLine(
            label: '순자산',
            value: formatKRW(netAssetTotal),
            valueColor: netAssetTotal >= 0
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFEF4444),
            strong: true,
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '비중은 부채를 제외한 자산 합계 기준입니다.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool strong;

  const _SummaryLine({
    required this.label,
    required this.value,
    required this.valueColor,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: strong ? 15 : 14,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 16 : 14,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _LiabilitySection extends StatelessWidget {
  final List<_AllocationItem> items;

  const _LiabilitySection({required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.valueKRW);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '부채',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                formatKRW(total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ),
                  Text(
                    formatKRW(item.valueKRW),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationResult {
  final List<_AllocationItem> items;
  final List<_AllocationItem> liabilities;

  const _AllocationResult({required this.items, required this.liabilities});
}

class _AllocationItem {
  final String label;
  final double valueKRW;
  final Color color;
  final String? subtitle;

  const _AllocationItem({
    required this.label,
    required this.valueKRW,
    required this.color,
    this.subtitle,
  });

  _AllocationItem copyWith({double? valueKRW}) {
    return _AllocationItem(
      label: label,
      valueKRW: valueKRW ?? this.valueKRW,
      color: color,
      subtitle: subtitle,
    );
  }
}
