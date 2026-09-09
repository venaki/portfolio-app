import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/portfolio_provider.dart';
import '../../engine/snapshot_engine.dart';
import '../../models/portfolio_snapshot.dart';
import '../../utils/format.dart';
import '../../utils/constants.dart';

class DashboardTrendView extends ConsumerStatefulWidget {
  const DashboardTrendView({super.key, required this.portfolio});
  final PortfolioState portfolio;
  @override
  ConsumerState<DashboardTrendView> createState() => _DashboardTrendViewState();
}

class _DashboardTrendViewState extends ConsumerState<DashboardTrendView> {
  bool _trendSnapshotsExpanded = false;
  int _trendSnapshotPage = 0;
  static const _trendSnapshotPageSize = 20;
  @override
  Widget build(BuildContext context) =>
      _buildTrendView(widget.portfolio, ref.watch(dashboardTrendRangeProvider));
  Widget _buildTrendView(PortfolioState portfolio, String trendRange) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final allSnapshots = filterSnapshotRange(portfolio.snapshots, '전체');
    final snapshots = filterSnapshotRange(allSnapshots, trendRange);
    if (snapshots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrendRangeSelector(trendRange, accentColor),
          const SizedBox(height: 12),
          _buildComingSoonView(
            icon: Icons.show_chart,
            title: '추이',
            description: allSnapshots.isEmpty
                ? '아직 저장된 스냅샷이 없습니다. 새로고침 후 오늘 자산 현황이 기록됩니다.'
                : '선택한 기간에 표시할 스냅샷이 없습니다.',
          ),
          const SizedBox(height: 12),
          _buildHistorySection(portfolio, allSnapshots),
        ],
      );
    }

    final periodStart = snapshots.first;
    final latest = snapshots.last;
    final hasHistory = snapshots.length >= 2;
    final periodChangeKRW = latest.totalValueKRW - periodStart.totalValueKRW;
    final periodChangePct = periodStart.totalValueKRW > 0
        ? (periodChangeKRW / periodStart.totalValueKRW) * 100
        : 0.0;
    final changePositive = periodChangeKRW >= 0;
    final stale =
        snapshots.any((snapshot) => snapshot.needsRebuild) ||
        portfolio.historyDirtyFrom != null;
    final origin = DateTime.parse(periodStart.date);
    final lastX = snapshotXAxis(DateTime.parse(latest.date), origin);
    final values = snapshots
        .expand((s) => [s.totalValueKRW, s.totalCostKRW])
        .toList();
    final interval = trendAxisInterval(values);
    final minY =
        (values.reduce((a, b) => a < b ? a : b) / interval).floor() * interval;
    final maxY =
        (values.reduce((a, b) => a > b ? a : b) / interval).ceil() * interval;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTrendRangeSelector(trendRange, accentColor),
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
              const Text(
                '투자 자산',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (stale)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '과거 거래 변경으로 재계산이 필요합니다. 이전 순자산 기록입니다.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                formatKRW(latest.totalValueKRW),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (hasHistory)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                    children: [
                      TextSpan(text: '${snapshotComparisonLabel(snapshots)} '),
                      TextSpan(
                        text:
                            '${changePositive ? '+' : ''}${formatKRW(periodChangeKRW)}${periodStart.totalValueKRW > 0 ? ' (${formatPercent(periodChangePct)})' : ''}',
                        style: TextStyle(
                          color: changePositive ? positiveColor : negativeColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  '오늘부터 자산 추이 기록을 시작했어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '원금 ${formatKRW(latest.totalCostKRW)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TrendMetric(
                      label: '수익',
                      value: _formatSignedKrw(latest.profitKRW),
                      valueColor: latest.profitKRW >= 0
                          ? positiveColor
                          : negativeColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TrendMetric(
                      label: '수익률',
                      value: formatPercent(latest.profitPct),
                      valueColor: latest.profitPct >= 0
                          ? positiveColor
                          : negativeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (hasHistory) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TrendLegend(color: accentColor, label: '자산'),
                    SizedBox(width: 16),
                    _TrendLegend(color: Color(0xFFBFC5CD), label: '원금'),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 260,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: lastX > 0 ? lastX : 1,
                      minY: minY,
                      maxY: maxY > minY ? maxY : minY + interval,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final snapshot = snapshots[spot.spotIndex];
                              final isAsset = spot.barIndex == 0;
                              final value = isAsset
                                  ? snapshot.totalValueKRW
                                  : snapshot.totalCostKRW;
                              return LineTooltipItem(
                                '${snapshot.date.substring(5)}\n${isAsset ? '자산' : '원금'} ${formatKRW(value)}',
                                const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFF1F3F5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          left: BorderSide(color: Color(0xFFE5E7EB)),
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
                            reservedSize: 52,
                            interval: interval,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                _compactKrw(value),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: _bottomTitleInterval(lastX.toInt() + 1),
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value > lastX) {
                                return const SizedBox.shrink();
                              }
                              final date = origin
                                  .add(Duration(days: value.round()))
                                  .toIso8601String()
                                  .substring(0, 10);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  date.length >= 10
                                      ? '${date.substring(5, 7)}.${date.substring(8, 10)}'
                                      : date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: snapshots.indexed
                              .map(
                                (entry) => FlSpot(
                                  snapshotXAxis(
                                    DateTime.parse(entry.$2.date),
                                    origin,
                                  ),
                                  entry.$2.totalValueKRW,
                                ),
                              )
                              .toList(),
                          isCurved: false,
                          color: accentColor,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) => spot.x == lastX,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: accentColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                          ),
                        ),
                        LineChartBarData(
                          spots: snapshots.indexed
                              .map(
                                (entry) => FlSpot(
                                  snapshotXAxis(
                                    DateTime.parse(entry.$2.date),
                                    origin,
                                  ),
                                  entry.$2.totalCostKRW,
                                ),
                              )
                              .toList(),
                          isCurved: false,
                          color: const Color(0xFFBFC5CD),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildHistorySection(portfolio, allSnapshots),
        if (!hasHistory) ...[
          const SizedBox(height: 12),
          const Text(
            '스냅샷이 2개 이상 쌓이면 추이 그래프가 표시됩니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildHistorySection(
    PortfolioState portfolio,
    List<PortfolioSnapshot> allSnapshots,
  ) {
    final pagedSnapshots = allSnapshots.reversed.toList();
    final totalPages = pagedSnapshots.isEmpty
        ? 1
        : ((pagedSnapshots.length - 1) ~/ _trendSnapshotPageSize) + 1;
    if (_trendSnapshotPage >= totalPages) {
      _trendSnapshotPage = totalPages - 1;
    }
    final pageStart = _trendSnapshotPage * _trendSnapshotPageSize;
    final pageEnd = (pageStart + _trendSnapshotPageSize).clamp(
      0,
      pagedSnapshots.length,
    );
    final currentPageItems = pagedSnapshots.sublist(pageStart, pageEnd);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _trendSnapshotsExpanded = !_trendSnapshotsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '스냅샷 기록 / 복원',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Text(
                    '${pagedSnapshots.length}개',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _trendSnapshotsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: const Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),
          if (_trendSnapshotsExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    portfolio.backfillMessage ??
                        '설정에서 과거 가격 CSV를 가져온 뒤 최근 1년 일별 추이를 복원할 수 있습니다.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: !portfolio.canWrite
                        ? null
                        : () => ref
                              .read(portfolioProvider.notifier)
                              .backfillOneYearSnapshots(),
                    icon: portfolio.isBackfilling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.history),
                    label: Text(
                      portfolio.isBackfilling ? '복원 중' : '최근 1년 추이 복원',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
            ...currentPageItems.map((snapshot) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.date,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${snapshot.source} · ${snapshot.needsRebuild ? '재계산 필요' : formatRelativeTime(snapshot.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatKRW(snapshot.totalValueKRW),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (totalPages > 1) ...[
              const Divider(height: 1, color: Color(0xFFE5E5E5)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _trendSnapshotPage > 0
                          ? () {
                              setState(() {
                                _trendSnapshotPage -= 1;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '이전 페이지',
                    ),
                    Expanded(
                      child: Text(
                        '${_trendSnapshotPage + 1} / $totalPages',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _trendSnapshotPage < totalPages - 1
                          ? () {
                              setState(() {
                                _trendSnapshotPage += 1;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '다음 페이지',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTrendRangeSelector(String selected, Color accentColor) {
    const options = ['올해', '1개월', '3개월', '6개월', '1년', '전체'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(dashboardTrendRangeProvider.notifier).state = option,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: options.length,
      ),
    );
  }

  double _bottomTitleInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 31) return 5;
    if (count <= 93) return 14;
    if (count <= 186) return 30;
    return 60;
  }

  String _compactKrw(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}억';
    }
    if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}만';
    }
    return value.toStringAsFixed(0);
  }

  String _formatSignedKrw(double value) {
    final prefix = value >= 0 ? '+' : '-';
    return '$prefix${formatKRW(value.abs())}';
  }

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

class _TrendLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _TrendLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

class _TrendMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _TrendMetric({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
