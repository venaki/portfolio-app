import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import '../engine/calculations.dart';
import '../engine/holdings_engine.dart';
import '../utils/format.dart';
import '../utils/constants.dart';
import 'transaction_card.dart';

Future<void> showHoldingTransactionsDialog(
  BuildContext context, {
  required String ticker,
  required String displayName,
  required String account,
  required String broker,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Center(
      child: HoldingTransactionsModal(
        ticker: ticker, displayName: displayName,
        account: account, broker: broker,
      ),
    ),
  );
}

class HoldingTransactionsModal extends ConsumerStatefulWidget {
  final String ticker;
  final String displayName;
  final String account;
  final String broker;

  const HoldingTransactionsModal({
    super.key,
    required this.ticker,
    required this.displayName,
    required this.account,
    required this.broker,
  });

  @override
  ConsumerState<HoldingTransactionsModal> createState() => _HoldingTransactionsModalState();
}

class _HoldingTransactionsModalState extends ConsumerState<HoldingTransactionsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _periodFilter = '전체';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final transactions = portfolio.transactions
        .where((tx) => tx.ticker == widget.ticker
            && tx.account == widget.account
            && tx.broker == widget.broker)
        .toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: 종목명 + 닫기
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 22, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1A1A1A),
              unselectedLabelColor: const Color(0xFFAAAAAA),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              indicatorColor: const Color(0xFF1A1A1A),
              indicatorWeight: 2,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(text: '거래내역'),
                Tab(text: '실현손익'),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransactionsTab(transactions, portfolio),
                  _buildRealizedPLTab(transactions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 거래내역 탭 ───

  Widget _buildTransactionsTab(List<Transaction> transactions, dynamic portfolio) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text('거래내역이 없습니다', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final tx = transactions[i];
        return Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: TransactionCard(
            transaction: tx,
            stockName: portfolio.quotes[tx.ticker]?.name,
          ),
        );
      },
    );
  }

  // ─── 실현손익 탭 ───

  Widget _buildRealizedPLTab(List<Transaction> allTx) {
    // 매도 거래만 추출
    final sells = allTx.where((tx) => tx.type == TransactionType.sell).toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    // 기간 필터 적용
    final filteredSells = _filterByPeriod(sells);

    // 매도 시점의 평단가 계산을 위해 거래를 시간순으로 리플레이
    final plItems = _calcRealizedPLList(allTx, filteredSells);

    final isKRW = allTx.isNotEmpty && allTx.first.currency == Currency.krw;

    // 합계
    double totalPLNative = 0;
    double totalPLKRW = 0;
    for (final item in plItems) {
      totalPLNative += item.plNative;
      totalPLKRW += item.plKRW;
    }

    return Column(
      children: [
        // 기간 필터
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: ['전체', '1개월', '3개월', '6개월', '1년'].map((period) {
              final isSelected = _periodFilter == period;
              return GestureDetector(
                onTap: () => setState(() => _periodFilter = period),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFAAAAAA),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 2,
                        width: 20,
                        color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 합계
        if (plItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('합계', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isKRW)
                      Text(
                        '${totalPLNative >= 0 ? '+' : ''}${formatUSD(totalPLNative)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: totalPLNative >= 0 ? positiveColor : negativeColor,
                        ),
                      ),
                    Text(
                      '${totalPLKRW >= 0 ? '+' : ''}${formatKRW(totalPLKRW)}',
                      style: TextStyle(
                        fontSize: isKRW ? 15 : 12,
                        fontWeight: isKRW ? FontWeight.w700 : FontWeight.w500,
                        color: totalPLKRW >= 0 ? positiveColor : negativeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),

        // 실현손익 리스트
        if (plItems.isEmpty)
          const Expanded(
            child: Center(
              child: Text('실현손익이 없습니다', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: plItems.length,
              itemBuilder: (_, i) {
                final item = plItems[i];
                final plColor = item.plKRW >= 0 ? positiveColor : negativeColor;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: const Color(0xFFF0F0F0))),
                  ),
                  child: Row(
                    children: [
                      // 좌: 날짜 + 수량×가격
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.date,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                            const SizedBox(height: 2),
                            Text(
                              isKRW
                                  ? '${formatShares(item.shares)}주 × ${formatKRW(item.sellPrice)}'
                                  : '${formatShares(item.shares)}주 × ${formatUSD(item.sellPrice)} · ₩${formatShares(item.sellRate)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                            ),
                          ],
                        ),
                      ),
                      // 우: 실현손익
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isKRW)
                            Text(
                              '${item.plNative >= 0 ? '+' : ''}${formatUSD(item.plNative)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: plColor),
                            ),
                          Text(
                            '${item.plKRW >= 0 ? '+' : ''}${formatKRW(item.plKRW)}',
                            style: TextStyle(
                              fontSize: isKRW ? 13 : 11,
                              fontWeight: isKRW ? FontWeight.w600 : FontWeight.w500,
                              color: plColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // 경고문구
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '각 증권사의 거래 수수료가 포함되지 않은 금액입니다.',
            style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
          ),
        ),
      ],
    );
  }

  List<Transaction> _filterByPeriod(List<Transaction> sells) {
    if (_periodFilter == '전체') return sells;
    final now = DateTime.now();
    final Duration duration;
    switch (_periodFilter) {
      case '1개월': duration = const Duration(days: 30); break;
      case '3개월': duration = const Duration(days: 90); break;
      case '6개월': duration = const Duration(days: 180); break;
      case '1년': duration = const Duration(days: 365); break;
      default: return sells;
    }
    final cutoff = now.subtract(duration);
    return sells.where((tx) {
      final d = DateTime.tryParse(tx.date);
      return d != null && d.isAfter(cutoff);
    }).toList();
  }

  /// 매도 거래별 실현손익 계산 (FIFO 기반 평단가)
  List<_RealizedPLItem> _calcRealizedPLList(
    List<Transaction> allTx,
    List<Transaction> targetSells,
  ) {
    // 시간순 정렬하여 평단가 추적
    final sorted = List<Transaction>.from(allTx)
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    double avgCost = 0;
    double avgRate = 0;
    double totalShares = 0;
    final targetIds = targetSells.map((s) => s.id).toSet();
    final results = <_RealizedPLItem>[];

    for (final tx in sorted) {
      if (tx.type == TransactionType.buy ||
          tx.type == TransactionType.openingBalance ||
          tx.type == TransactionType.adjustment) {
        final newTotal = totalShares + tx.shares;
        if (newTotal > 0) {
          avgCost = (totalShares * avgCost + tx.shares * tx.price) / newTotal;
          avgRate = (totalShares * avgRate + tx.shares * tx.exchangeRate) / newTotal;
        }
        totalShares = newTotal;
      } else if (tx.type == TransactionType.sell) {
        if (targetIds.contains(tx.id)) {
          final pl = calcRealizedPL(tx.shares, tx.price, tx.exchangeRate, avgCost, avgRate);
          results.add(_RealizedPLItem(
            date: tx.date,
            shares: tx.shares,
            sellPrice: tx.price,
            sellRate: tx.exchangeRate,
            avgCost: avgCost,
            avgRate: avgRate,
            plNative: pl.usd,
            plKRW: tx.currency == Currency.krw ? pl.usd : pl.krw,
          ));
        }
        totalShares -= tx.shares;
        if (totalShares < 0) totalShares = 0;
      }
    }

    // 날짜 내림차순으로 반환
    return results.reversed.toList();
  }
}

class _RealizedPLItem {
  final String date;
  final double shares;
  final double sellPrice;
  final double sellRate;
  final double avgCost;
  final double avgRate;
  final double plNative; // USD 또는 KRW (네이티브 통화)
  final double plKRW;

  const _RealizedPLItem({
    required this.date,
    required this.shares,
    required this.sellPrice,
    required this.sellRate,
    required this.avgCost,
    required this.avgRate,
    required this.plNative,
    required this.plKRW,
  });
}
