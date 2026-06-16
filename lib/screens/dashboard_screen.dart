import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
import '../engine/calculations.dart';
import '../widgets/total_asset_card.dart';
import '../widgets/account_card.dart';
import '../widgets/type_group_card.dart';
import '../widgets/segmented_filter.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _wasLoading = false;
  int _allocationSelectedIndex = 0;
  bool _trendSnapshotsExpanded = false;
  int _trendSnapshotPage = 0;

  static const int _trendSnapshotPageSize = 20;

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final viewMode = ref.watch(dashboardViewModeProvider);
    final analysisTab = ref.watch(dashboardAnalysisTabProvider);
    final allocationMode = ref.watch(dashboardAllocationModeProvider);
    final trendRange = ref.watch(dashboardTrendRangeProvider);

    // 로딩 완료 감지 → SnackBar
    if (_wasLoading && !portfolio.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('업데이트 완료'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            ),
          );
        }
      });
    }
    _wasLoading = portfolio.isLoading;

    if (portfolio.isLoading && portfolio.holdings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 총자산 계산
    double totalValueKRW = 0;
    double totalCostKRW = 0;
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      totalValueKRW += calcTotalValueKRW(h, price, portfolio.exchangeRate);
      totalCostKRW += calcCostKRW(h);
    }

    // 기타 자산 합산 (통합 자산 사용)
    for (final ca in portfolio.consolidatedOtherAssets) {
      final raw = ca.category == AssetCategory.loan
          ? -ca.totalValue.abs()
          : ca.totalValue;
      final v = ca.currency == Currency.krw
          ? raw
          : raw * portfolio.exchangeRate;
      totalValueKRW += v;
      totalCostKRW += v;
    }

    final totalProfitKRW = totalValueKRW - totalCostKRW;
    final totalProfitPct = totalCostKRW > 0
        ? (totalProfitKRW / totalCostKRW) * 100
        : 0.0;
    final totalValueUSD = portfolio.exchangeRate > 0
        ? totalValueKRW / portfolio.exchangeRate
        : 0.0;

    // 어제 대비 일간 변동
    double dailyChangeKRW = 0;
    double totalYestValueKRW = 0;
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      dailyChangeKRW += calcDailyChangeKRW(
        h,
        price,
        closeYest,
        portfolio.exchangeRate,
      );
      totalYestValueKRW += calcTotalValueKRW(
        h,
        closeYest,
        portfolio.exchangeRate,
      );
    }
    final dailyChangePct = totalYestValueKRW > 0
        ? (dailyChangeKRW / totalYestValueKRW) * 100
        : 0.0;

    // 계좌별 집계 + 서브카테고리
    final accountMap =
        <
          String,
          ({
            double value,
            double cost,
            double dailyChange,
            double yestValue,
            double usValue,
            double krValue,
            double otherValue,
          })
        >{};
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      final val = calcTotalValueKRW(h, price, portfolio.exchangeRate);
      final cost = calcCostKRW(h);
      final daily = calcDailyChangeKRW(
        h,
        price,
        closeYest,
        portfolio.exchangeRate,
      );
      final yest = calcTotalValueKRW(h, closeYest, portfolio.exchangeRate);
      final isUS = h.market == Market.us;
      final isKR = h.market == Market.krx || h.market == Market.kosdaq;

      final entry =
          accountMap[h.account] ??
          (
            value: 0.0,
            cost: 0.0,
            dailyChange: 0.0,
            yestValue: 0.0,
            usValue: 0.0,
            krValue: 0.0,
            otherValue: 0.0,
          );
      accountMap[h.account] = (
        value: entry.value + val,
        cost: entry.cost + cost,
        dailyChange: entry.dailyChange + daily,
        yestValue: entry.yestValue + yest,
        usValue: entry.usValue + (isUS ? val : 0),
        krValue: entry.krValue + (isKR ? val : 0),
        otherValue: entry.otherValue,
      );
    }
    for (final ca in portfolio.consolidatedOtherAssets) {
      final raw = ca.category == AssetCategory.loan
          ? -ca.totalValue.abs()
          : ca.totalValue;
      final v = ca.currency == Currency.krw
          ? raw
          : raw * portfolio.exchangeRate;
      final entry =
          accountMap[ca.account] ??
          (
            value: 0.0,
            cost: 0.0,
            dailyChange: 0.0,
            yestValue: 0.0,
            usValue: 0.0,
            krValue: 0.0,
            otherValue: 0.0,
          );
      accountMap[ca.account] = (
        value: entry.value + v,
        cost: entry.cost + v,
        dailyChange: entry.dailyChange,
        yestValue: entry.yestValue + v,
        usValue: entry.usValue,
        krValue: entry.krValue,
        otherValue: entry.otherValue + v,
      );
    }

    // 업데이트 시간
    String updateTimeText = '';
    if (portfolio.lastUpdated != null) {
      final t = portfolio.lastUpdated!;
      updateTimeText =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 업데이트';
    }

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedFilter(
                    options: const ['현황', '추이', '비중'],
                    selected: analysisTab,
                    onChanged: (v) =>
                        ref.read(dashboardAnalysisTabProvider.notifier).state =
                            v,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: portfolio.isLoading && portfolio.holdings.isNotEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () => ref
                              .read(portfolioProvider.notifier)
                              .refreshPrices(force: true),
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF888888),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 16,
                          tooltip: '새로고침',
                        ),
                ),
              ],
            ),
          ),

          if (analysisTab == '추이') ...[
            _buildTrendView(portfolio, trendRange),
          ] else if (analysisTab == '비중') ...[
            _buildAllocationView(
              portfolio: portfolio,
              mode: allocationMode,
              isWide: isWide,
            ),
          ] else ...[
            // Total Asset Card
            TotalAssetCard(
              totalValueKRW: totalValueKRW,
              totalValueUSD: totalValueUSD,
              dailyChangeKRW: dailyChangeKRW,
              dailyChangePct: dailyChangePct,
              totalCostKRW: totalCostKRW,
              totalProfitKRW: totalProfitKRW,
              totalProfitPct: totalProfitPct,
            ),
            const SizedBox(height: 12),

            // Meta Row: exchange rate + update time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 USD = ${formatKRW(portfolio.exchangeRate)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                  ),
                ),
                if (updateTimeText.isNotEmpty)
                  Text(
                    updateTimeText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // View Mode Toggle
            SizedBox(
              width: 240,
              child: SegmentedFilter(
                options: const ['By Account', 'By Type'],
                selected: viewMode,
                onChanged: (v) =>
                    ref.read(dashboardViewModeProvider.notifier).state = v,
              ),
            ),
            const SizedBox(height: 12),

            // Conditional View
            if (viewMode == 'By Account') ...[
              // Account Cards — PC: 가로 배열, Mobile: 세로 배열
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      _sortedAccountEntries(
                        accountMap,
                        portfolio.settings.accounts,
                      ).indexed.map((e) {
                        final (index, entry) = e;
                        final v = entry.value;
                        final profit = v.value - v.cost;
                        final profitPct = v.cost > 0
                            ? (profit / v.cost) * 100
                            : 0.0;
                        final dailyPct = v.yestValue > 0
                            ? (v.dailyChange / v.yestValue) * 100
                            : 0.0;
                        final valueUSD = portfolio.exchangeRate > 0
                            ? v.value / portfolio.exchangeRate
                            : 0.0;
                        final subs = <String, double>{};
                        if (v.usValue != 0) subs['미국'] = v.usValue;
                        if (v.krValue != 0) subs['한국'] = v.krValue;
                        if (v.otherValue != 0) subs['기타'] = v.otherValue;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                            child: AccountCard(
                              account: entry.key,
                              color: getAccountColor(index),
                              valueKRW: v.value,
                              valueUSD: valueUSD,
                              dailyChangeKRW: v.dailyChange,
                              dailyChangePct: dailyPct,
                              profitKRW: profit,
                              profitPct: profitPct,
                              subCategories: subs,
                            ),
                          ),
                        );
                      }).toList(),
                )
              else
                ..._sortedAccountEntries(
                  accountMap,
                  portfolio.settings.accounts,
                ).indexed.map((e) {
                  final (index, entry) = e;
                  final v = entry.value;
                  final profit = v.value - v.cost;
                  final profitPct = v.cost > 0 ? (profit / v.cost) * 100 : 0.0;
                  final dailyPct = v.yestValue > 0
                      ? (v.dailyChange / v.yestValue) * 100
                      : 0.0;
                  final valueUSD = portfolio.exchangeRate > 0
                      ? v.value / portfolio.exchangeRate
                      : 0.0;
                  final subs = <String, double>{};
                  if (v.usValue != 0) subs['미국'] = v.usValue;
                  if (v.krValue != 0) subs['한국'] = v.krValue;
                  if (v.otherValue != 0) subs['기타'] = v.otherValue;

                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: AccountCard(
                      account: entry.key,
                      color: getAccountColor(index),
                      valueKRW: v.value,
                      valueUSD: valueUSD,
                      dailyChangeKRW: v.dailyChange,
                      dailyChangePct: dailyPct,
                      profitKRW: profit,
                      profitPct: profitPct,
                      subCategories: subs,
                    ),
                  );
                }),
            ] else ...[
              // By Type View
              ..._buildTypeView(portfolio),
            ],
          ],
        ],
      ),
    );
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

  Widget _buildTrendView(PortfolioState portfolio, String trendRange) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final allSnapshots = [...portfolio.snapshots]
      ..sort((a, b) => a.date.compareTo(b.date));
    final snapshots = _filterTrendSnapshots(allSnapshots, trendRange);
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

    if (allSnapshots.isEmpty) {
      return _buildComingSoonView(
        icon: Icons.show_chart,
        title: '추이',
        description: '아직 저장된 스냅샷이 없습니다. 새로고침 후 오늘 자산 현황이 기록됩니다.',
      );
    }

    if (snapshots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrendRangeSelector(trendRange, accentColor),
          const SizedBox(height: 12),
          _buildComingSoonView(
            icon: Icons.show_chart,
            title: '추이',
            description: '선택한 기간에 표시할 스냅샷이 없습니다.',
          ),
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
                      TextSpan(text: '${_trendRangeComparisonLabel(trendRange)} '),
                      TextSpan(
                        text:
                            '${changePositive ? '+' : ''}${formatKRW(periodChangeKRW)} (${formatPercent(periodChangePct)})',
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
                    _TrendLegend(
                      color: accentColor,
                      label: '자산',
                    ),
                    SizedBox(width: 16),
                    _TrendLegend(
                      color: Color(0xFFBFC5CD),
                      label: '원금',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 260,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (snapshots.length - 1).toDouble(),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final snapshot = snapshots[spot.x.toInt()];
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
                        horizontalInterval: _trendInterval(snapshots),
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
                            interval: _trendInterval(snapshots),
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
                            interval: _bottomTitleInterval(snapshots.length),
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= snapshots.length) {
                                return const SizedBox.shrink();
                              }
                              final date = snapshots[index].date;
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
                                  entry.$1.toDouble(),
                                  entry.$2.totalValueKRW,
                                ),
                              )
                              .toList(),
                          isCurved: false,
                          color: accentColor,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) =>
                                spot.x == snapshots.length - 1,
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
                                  entry.$1.toDouble(),
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
        Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                            '과거 거래내역 기준으로 최근 1년 일별 추이를 복원할 수 있습니다.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: portfolio.isBackfilling
                            ? null
                            : () => ref
                                  .read(portfolioProvider.notifier)
                                  .backfillOneYearSnapshots(),
                        icon: portfolio.isBackfilling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                '${snapshot.source} · ${formatRelativeTime(snapshot.createdAt)}',
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
        ),
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
                color: isSelected
                    ? accentColor
                    : const Color(0xFFF3F4F6),
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

  List<dynamic> _filterTrendSnapshots(List<dynamic> snapshots, String range) {
    if (snapshots.isEmpty || range == '전체') return snapshots;

    final latestDate = DateTime.tryParse(snapshots.last.date);
    if (latestDate == null) return snapshots;

    late final DateTime start;
    switch (range) {
      case '올해':
        start = DateTime(latestDate.year, 1, 1);
        break;
      case '1개월':
        start = latestDate.subtract(const Duration(days: 30));
        break;
      case '3개월':
        start = latestDate.subtract(const Duration(days: 90));
        break;
      case '6개월':
        start = latestDate.subtract(const Duration(days: 180));
        break;
      default:
        start = latestDate.subtract(const Duration(days: 365));
        break;
    }

    return snapshots.where((snapshot) {
      final date = DateTime.tryParse(snapshot.date);
      if (date == null) return false;
      return !date.isBefore(start);
    }).toList();
  }

  String _trendRangeComparisonLabel(String range) {
    switch (range) {
      case '올해':
        return '올해 시작보다';
      case '1개월':
        return '1개월 전보다';
      case '3개월':
        return '3개월 전보다';
      case '6개월':
        return '6개월 전보다';
      case '전체':
        return '첫 기록보다';
      default:
        return '1년 전보다';
    }
  }

  double _trendInterval(List<dynamic> snapshots) {
    final values = snapshots
        .expand<double>((snapshot) => [snapshot.totalValueKRW, snapshot.totalCostKRW])
        .toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return 1;
    return maxValue / 4;
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
      return _buildComingSoonView(
        icon: Icons.donut_large,
        title: '비중',
        description: '비중을 계산할 수 있는 양수 자산이 아직 없습니다.',
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

    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final value = calcTotalValueKRW(h, price, portfolio.exchangeRate);
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
            getAccountColor(portfolio.settings.accounts.indexOf(h.account)),
          );
          break;
        default:
          addPositive(
            'ticker:${h.ticker}',
            h.ticker,
            value,
            _allocationColor(positive.length),
            subtitle: quote?.name,
          );
      }
    }

    for (final ca in portfolio.consolidatedOtherAssets) {
      final raw = ca.category == AssetCategory.loan
          ? -ca.totalValue.abs()
          : ca.totalValue;
      final value = ca.currency == Currency.krw
          ? raw
          : raw * portfolio.exchangeRate;
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
              'asset:${ca.name}:${ca.account}',
              ca.name,
              value,
              const Color(0xFFEF4444),
              subtitle: ca.account,
            );
          } else {
            addPositive(
              'asset:${ca.name}:${ca.account}',
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

  List<
    MapEntry<
      String,
      ({
        double value,
        double cost,
        double dailyChange,
        double yestValue,
        double usValue,
        double krValue,
        double otherValue,
      })
    >
  >
  _sortedAccountEntries(
    Map<
      String,
      ({
        double value,
        double cost,
        double dailyChange,
        double yestValue,
        double usValue,
        double krValue,
        double otherValue,
      })
    >
    accountMap,
    List<String> accountOrder,
  ) {
    return accountMap.entries.toList()..sort((a, b) {
      final ai = accountOrder.indexOf(a.key);
      final bi = accountOrder.indexOf(b.key);
      final aIdx = ai == -1 ? accountOrder.length : ai;
      final bIdx = bi == -1 ? accountOrder.length : bi;
      return aIdx.compareTo(bIdx);
    });
  }

  List<Widget> _buildTypeView(PortfolioState portfolio) {
    // 같은 티커끼리 합산 (계좌/증권사 무관)
    final usMap = <String, HoldingRow>{};
    final krMap = <String, HoldingRow>{};

    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      final name = quote?.name ?? h.ticker;
      final valueKRW = calcTotalValueKRW(h, price, portfolio.exchangeRate);
      final costKRW = calcCostKRW(h);
      final dailyChange = calcDailyChangeKRW(
        h,
        price,
        closeYest,
        portfolio.exchangeRate,
      );
      final yestValue = calcTotalValueKRW(h, closeYest, portfolio.exchangeRate);

      final isUS = h.market == Market.us;
      final map = isUS ? usMap : krMap;
      final existing = map[h.ticker];
      if (existing != null) {
        map[h.ticker] = HoldingRow(
          name: name,
          ticker: h.ticker,
          valueKRW: existing.valueKRW + valueKRW,
          costKRW: existing.costKRW + costKRW,
          dailyChangeKRW: existing.dailyChangeKRW + dailyChange,
          yestValueKRW: existing.yestValueKRW + yestValue,
          shares: (existing.shares ?? 0) + h.shares,
        );
      } else {
        map[h.ticker] = HoldingRow(
          name: name,
          ticker: h.ticker,
          valueKRW: valueKRW,
          costKRW: costKRW,
          dailyChangeKRW: dailyChange,
          yestValueKRW: yestValue,
          shares: h.shares,
        );
      }
    }

    final usHoldings = usMap.values.toList()
      ..sort((a, b) => b.valueKRW.compareTo(a.valueKRW));
    final krHoldings = krMap.values.toList()
      ..sort((a, b) => b.valueKRW.compareTo(a.valueKRW));

    // 기타자산을 category별로 그룹핑 (통합 자산 사용)
    final otherByCategory = <AssetCategory, List<HoldingRow>>{};
    for (final ca in portfolio.consolidatedOtherAssets) {
      final raw = ca.category == AssetCategory.loan
          ? -ca.totalValue.abs()
          : ca.totalValue;
      final v = ca.currency == Currency.krw
          ? raw
          : raw * portfolio.exchangeRate;
      final row = HoldingRow(
        name: ca.name,
        ticker: ca.name,
        valueKRW: v,
        costKRW: v,
        dailyChangeKRW: 0,
        yestValueKRW: v,
      );
      (otherByCategory[ca.category] ??= []).add(row);
    }

    final categoryLabels = {
      AssetCategory.savings: '예금',
      AssetCategory.bond: '채권',
      AssetCategory.loan: '대출',
      AssetCategory.other: '기타',
    };

    final cards = <Widget>[];
    var index = 0;

    if (usHoldings.isNotEmpty) {
      cards.add(
        Padding(
          padding: EdgeInsets.only(top: index++ == 0 ? 0 : 8),
          child: TypeGroupCard(title: '미국주식', items: usHoldings),
        ),
      );
    }
    if (krHoldings.isNotEmpty) {
      cards.add(
        Padding(
          padding: EdgeInsets.only(top: index++ == 0 ? 0 : 8),
          child: TypeGroupCard(title: '한국주식', items: krHoldings),
        ),
      );
    }
    for (final cat in [
      AssetCategory.savings,
      AssetCategory.bond,
      AssetCategory.loan,
      AssetCategory.other,
    ]) {
      final items = otherByCategory[cat];
      if (items != null && items.isNotEmpty) {
        cards.add(
          Padding(
            padding: EdgeInsets.only(top: index++ == 0 ? 0 : 8),
            child: TypeGroupCard(title: categoryLabels[cat]!, items: items),
          ),
        );
      }
    }

    return cards;
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

class _TrendLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _TrendLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
