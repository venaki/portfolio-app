import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../widgets/segmented_filter.dart';
import '../widgets/transaction_card.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/edit_transaction_modal.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _marketFilter = '전체';
  String _accountFilter = '전체';
  String _typeFilter = '전체';
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final accentColor = Theme.of(context).colorScheme.primary;

    if (portfolio.isLoading && portfolio.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = ['전체', ...portfolio.settings.accounts];

    // 필터 적용
    final filtered = _applyFilters(portfolio.transactions);

    // 날짜 내림차순 정렬
    filtered.sort((a, b) => b.date.compareTo(a.date));

    // 월별 그룹핑
    final grouped = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = _monthKey(tx.date);
      (grouped[key] ??= []).add(tx);
    }

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
                '거래내역',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () => showAddTransactionDialog(context),
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

        // Filter: Account (always visible)
        SegmentedFilter(
          options: accounts,
          selected: _accountFilter,
          onChanged: (v) => setState(() => _accountFilter = v),
        ),
        const SizedBox(height: 8),

        // Expand/collapse toggle
        GestureDetector(
          onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _filtersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: const Color(0xFFAAAAAA),
              ),
              const SizedBox(width: 4),
              Text(
                _filtersExpanded ? '필터 접기' : '필터 더보기',
                style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Collapsible filters: Market + Type
        if (_filtersExpanded) ...[
          SegmentedFilter(
            options: const ['전체', '미국', '한국'],
            selected: _marketFilter,
            onChanged: (v) => setState(() => _marketFilter = v),
          ),
          const SizedBox(height: 8),
          SegmentedFilter(
            options: const ['전체', '매수', '매도'],
            selected: _typeFilter,
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),

        // Empty state
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                '거래내역이 없습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
          ),

        // Month groups
        ...grouped.entries.expand((entry) => [
              // Month label
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
              // Transaction cards
              ...entry.value.map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionCard(
                    transaction: tx,
                    onTap: () => showEditTransactionDialog(context, tx),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ]),
      ],
    );
  }

  List<Transaction> _applyFilters(List<Transaction> txs) {
    return txs.where((tx) {
      // Market filter
      if (_marketFilter == '미국' && tx.market != Market.us) return false;
      if (_marketFilter == '한국' &&
          tx.market != Market.krx &&
          tx.market != Market.kosdaq) return false;

      // Account filter
      if (_accountFilter != '전체' && tx.account != _accountFilter) {
        return false;
      }

      // Type filter
      if (_typeFilter == '매수' && tx.type == TransactionType.sell) {
        return false;
      }
      if (_typeFilter == '매도' && tx.type != TransactionType.sell) {
        return false;
      }

      return true;
    }).toList();
  }

  /// "2026-03-15" → "2026년 03월"
  String _monthKey(String date) {
    if (date.length < 7) return date;
    final year = date.substring(0, 4);
    final month = date.substring(5, 7);
    return '$year년 $month월';
  }
}
