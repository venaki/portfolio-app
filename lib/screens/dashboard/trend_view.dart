import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/portfolio_provider.dart';
import '../../engine/snapshot_engine.dart';
import '../../models/portfolio_snapshot.dart';
import '../../utils/format.dart';

class DashboardTrendView extends ConsumerStatefulWidget {
  const DashboardTrendView({super.key, required this.portfolio});
  final PortfolioState portfolio;
  @override
  ConsumerState<DashboardTrendView> createState() => _DashboardTrendViewState();
}

class _DashboardTrendViewState extends ConsumerState<DashboardTrendView> {
  bool _expanded = false;
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final state = widget.portfolio;
    final range = ref.watch(dashboardTrendRangeProvider);
    final all = filterSnapshotRange(state.snapshots, '전체');
    final snapshots = filterSnapshotRange(all, range);
    final reverse = all.reversed.toList();
    final pages = reverse.isEmpty ? 1 : (reverse.length / 20).ceil();
    final page = _page.clamp(0, pages - 1);
    final shown = reverse.skip(page * 20).take(20);
    final stale =
        snapshots.any((snapshot) => snapshot.needsRebuild) ||
        state.historyDirtyFrom != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in ['올해', '1개월', '3개월', '6개월', '1년', '전체'])
              ChoiceChip(
                label: Text(value),
                selected: value == range,
                onSelected: (_) =>
                    ref.read(dashboardTrendRangeProvider.notifier).state =
                        value,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (stale)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '과거 거래 수정 또는 계산 기준 변경으로 추이를 다시 계산해야 합니다. 아래 값은 이전 기록입니다.',
              ),
            ),
          ),
        if (snapshots.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '선택한 기간에 스냅샷이 없습니다. 과거 가격을 가져온 뒤 아래에서 추이를 복원할 수 있습니다.',
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stale ? '이전 순자산 기록' : '순자산 추이',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatKRW(snapshots.last.totalValueKRW),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text('${snapshots.last.date} 기준'),
                  if (snapshots.length > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${snapshotComparisonLabel(snapshots)} ${formatKRW(snapshots.last.totalValueKRW - snapshots.first.totalValueKRW)}'
                      '${snapshots.first.totalValueKRW > 0 ? ' (${formatPercent((snapshots.last.totalValueKRW - snapshots.first.totalValueKRW) / snapshots.first.totalValueKRW * 100)})' : ''}',
                    ),
                    const Text(
                      '입출금과 매수·매도에 따른 자산 변화를 포함합니다.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('보유 원가 ${formatKRW(snapshots.last.totalCostKRW)}'),
                  Text(
                    '평가손익 ${formatKRW(snapshots.last.profitKRW)} (${formatPercent(snapshots.last.profitPct)})',
                  ),
                ],
              ),
            ),
          ),
        if (snapshots.length > 1) ...[
          const SizedBox(height: 12),
          _chart(context, snapshots),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('과거 가격으로 추이 복원'),
                const SizedBox(height: 8),
                Text(
                  state.backfillMessage ??
                      '설정에서 과거 가격 CSV를 가져온 뒤 최근 1년의 일별 자산을 계산합니다.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: !state.canWrite
                      ? null
                      : () => ref
                            .read(portfolioProvider.notifier)
                            .backfillOneYearSnapshots(),
                  icon: state.isBackfilling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history),
                  label: Text(state.isBackfilling ? '복원 중' : '최근 1년 추이 복원'),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (value) => setState(() => _expanded = value),
            title: Text('스냅샷 기록 ${all.length}개'),
            children: [
              for (final snapshot in shown)
                ListTile(
                  title: Text(snapshot.date),
                  subtitle: Text(
                    '${snapshot.source} · ${snapshot.needsRebuild ? '재계산 필요' : formatRelativeTime(snapshot.createdAt)}',
                  ),
                  trailing: Text(formatKRW(snapshot.totalValueKRW)),
                ),
              if (pages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '이전 페이지',
                      onPressed: page > 0
                          ? () => setState(() => _page = page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${page + 1} / $pages'),
                    IconButton(
                      tooltip: '다음 페이지',
                      onPressed: page + 1 < pages
                          ? () => setState(() => _page = page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chart(BuildContext context, List<PortfolioSnapshot> snapshots) {
    final origin = DateTime.parse(snapshots.first.date);
    final lastX = snapshotXAxis(DateTime.parse(snapshots.last.date), origin);
    final values = snapshots
        .expand((snapshot) => [snapshot.totalValueKRW, snapshot.totalCostKRW])
        .toList();
    final interval = trendAxisInterval(values);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final minY = (min / interval).floor() * interval;
    final maxY = (max / interval).ceil() * interval;
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
        child: Column(
          children: [
            Wrap(
              spacing: 16,
              children: [
                Text('● 순자산', style: TextStyle(color: color)),
                const Text('● 보유 원가', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: lastX > 0 ? lastX : 1,
                  minY: minY,
                  maxY: maxY > minY ? maxY : minY + interval,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        final snapshot = snapshots[spot.spotIndex];
                        return LineTooltipItem(
                          '${snapshot.date}\n${spot.barIndex == 0 ? '순자산' : '보유 원가'} ${formatKRW(spot.y)}',
                          const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        interval: interval,
                        getTitlesWidget: (value, _) => Text(
                          _compact(value),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (lastX / 4).ceilToDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        getTitlesWidget: (value, _) {
                          final date = origin.add(
                            Duration(days: value.round()),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.month}.${date.day}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    for (final isValue in [true, false])
                      LineChartBarData(
                        spots: snapshots
                            .map(
                              (snapshot) => FlSpot(
                                snapshotXAxis(
                                  DateTime.parse(snapshot.date),
                                  origin,
                                ),
                                isValue
                                    ? snapshot.totalValueKRW
                                    : snapshot.totalCostKRW,
                              ),
                            )
                            .toList(),
                        color: isValue ? color : Colors.grey,
                        barWidth: 2,
                        isCurved: false,
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double value) {
    if (value.abs() >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}억';
    }
    if (value.abs() >= 10000) return '${(value / 10000).toStringAsFixed(0)}만';
    return value.toStringAsFixed(0);
  }
}
