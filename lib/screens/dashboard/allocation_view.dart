import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../engine/portfolio_valuation.dart';
import '../../models/transaction.dart';
import '../../providers/portfolio_provider.dart';
import '../../utils/format.dart';
import '../../widgets/segmented_filter.dart';

class DashboardAllocationView extends ConsumerStatefulWidget {
  const DashboardAllocationView({super.key, required this.valuation});
  final PortfolioValuation valuation;
  @override
  ConsumerState<DashboardAllocationView> createState() =>
      _DashboardAllocationViewState();
}

class _DashboardAllocationViewState
    extends ConsumerState<DashboardAllocationView> {
  String? _selectedKey;
  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFE11D48),
    Color(0xFFF59E0B),
    Color(0xFF16A34A),
  ];
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(dashboardAllocationModeProvider);
    final assets = <String, double>{}, liabilities = <String, double>{};
    void add(String key, double? value) {
      if (value == null || value == 0 || !value.isFinite) return;
      final map = value < 0 ? liabilities : assets;
      map[key] = (map[key] ?? 0) + value.abs();
    }

    for (final position in widget.valuation.positions) {
      final h = position.holding;
      final key = switch (mode) {
        '계좌별' => h.account,
        '유형별' => h.market == Market.us ? '미국주식' : '한국주식',
        _ => '${h.market.toSheetValue()} · ${h.ticker}',
      };
      add(key, position.valueKRW);
    }
    for (final value in widget.valuation.assets) {
      final asset = value.asset;
      final key = switch (mode) {
        '계좌별' => asset.account,
        '유형별' => asset.categoryLabel,
        _ =>
          '${asset.name} · ${asset.account} · ${asset.categoryLabel} · ${asset.currency.name.toUpperCase()}',
      };
      add(key, value.valueKRW);
    }
    final entries = assets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtEntries = liabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final debt = debtEntries.fold<double>(0, (sum, entry) => sum + entry.value);
    final selected =
        entries.where((entry) => entry.key == _selectedKey).firstOrNull ??
        entries.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedFilter(
          options: const ['종목별', '유형별', '계좌별'],
          selected: mode,
          onChanged: (value) {
            setState(() => _selectedKey = null);
            ref.read(dashboardAllocationModeProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                Text('양수 자산 ${formatKRW(total)}'),
                Text('부채·음수 잔액 ${formatKRW(debt)}'),
                Text('순자산 ${formatKRW(total - debt)}'),
              ],
            ),
          ),
        ),
        if (!widget.valuation.isComplete)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('확인된 평가금액 기준 비중입니다. 일부 시세는 누락되거나 이전 시세입니다.'),
          ),
        if (selected != null && total > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    selected.key,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${formatKRW(selected.value)} · ${(selected.value / total * 100).toStringAsFixed(2)}%',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 55,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) return;
                            final index =
                                response?.touchedSection?.touchedSectionIndex ??
                                -1;
                            if (index >= 0 && index < entries.length) {
                              setState(() => _selectedKey = entries[index].key);
                            }
                          },
                        ),
                        sections: entries.indexed
                            .map(
                              (entry) => PieChartSectionData(
                                value: entry.$2.value,
                                color: _colors[entry.$1 % _colors.length],
                                radius: entry.$2.key == selected.key ? 68 : 58,
                                showTitle: false,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final indexed in entries.indexed)
                    ListTile(
                      selected: indexed.$2.key == selected.key,
                      leading: Icon(
                        Icons.circle,
                        color: _colors[indexed.$1 % _colors.length],
                        size: 14,
                      ),
                      title: Text(indexed.$2.key),
                      subtitle: Text(formatKRW(indexed.$2.value)),
                      trailing: Text(
                        '${(indexed.$2.value / total * 100).toStringAsFixed(2)}%',
                      ),
                      onTap: () =>
                          setState(() => _selectedKey = indexed.$2.key),
                    ),
                ],
              ),
            ),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('비중을 계산할 양수 자산이 없습니다.'),
            ),
          ),
        if (debtEntries.isNotEmpty)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('부채·음수 잔액 (차트 분모에서 제외)'),
                ),
                for (final entry in debtEntries)
                  ListTile(
                    title: Text(entry.key),
                    trailing: Text(formatKRW(-entry.value)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
