import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/edit_transaction_modal.dart';
import '../providers/filter_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final _marketFilter = ref.watch(historyMarketFilter);
    final _accountFilter = ref.watch(historyAccountFilter);
    final _typeFilter = ref.watch(historyTypeFilter);
    final _brokerFilter = ref.watch(historyBrokerFilter);
    final _filterExpanded = ref.watch(historyFilterExpanded);
    final accentColor = Theme.of(context).colorScheme.primary;

    if (portfolio.isLoading && portfolio.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = ['전체', ...portfolio.settings.accounts];
    final filtered = _applyFilters(portfolio.transactions,
      marketFilter: _marketFilter, accountFilter: _accountFilter,
      typeFilter: _typeFilter, brokerFilter: _brokerFilter);
    filtered.sort((a, b) => b.date.compareTo(a.date));

    final grouped = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = _monthKey(tx.date);
      (grouped[key] ??= []).add(tx);
    }

    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionDialog(context),
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 80),
        children: [
          // Row 1: Account 필터 (좌측 상단, pill 스타일)
          _buildAccountFilter(accounts),
          const SizedBox(height: 16),

          // Row 2: Filter toggle (좌) + Market underline (우)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterToggle(),
              _buildMarketFilter(),
            ],
          ),

          // Expandable filters
          if (_filterExpanded) ...[
            const SizedBox(height: 12),
            _buildExpandedFilters(portfolio.settings.brokers),
          ],
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('거래내역이 없습니다',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ),
            ),

          ...grouped.entries.expand((entry) => [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFF888888)),
                  ),
                ),
                ...entry.value.map(
                  (tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TransactionCard(
                      transaction: tx,
                      stockName: portfolio.quotes[tx.ticker]?.name,
                      onTap: () => showEditTransactionDialog(context, tx),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
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
        final isSelected = account == ref.watch(historyAccountFilter);
        return GestureDetector(
          onTap: () => ref.read(historyAccountFilter.notifier).state = account,
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

  Widget _buildFilterToggle() {
    final hasActiveFilter = ref.watch(historyTypeFilter) != '전체' || ref.watch(historyBrokerFilter) != '전체';
    return GestureDetector(
      onTap: () => ref.read(historyFilterExpanded.notifier).state = !ref.read(historyFilterExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasActiveFilter ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: hasActiveFilter ? null : Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ref.watch(historyFilterExpanded) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: hasActiveFilter ? Colors.white : const Color(0xFF888888),
            ),
            const SizedBox(width: 4),
            Text(
              '필터',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasActiveFilter ? FontWeight.w600 : FontWeight.w400,
                color: hasActiveFilter ? Colors.white : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFilters(List<String> brokers) {
    const types = ['전체', '매수', '매도'];
    final brokerOptions = ['전체', ...brokers];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 거래유형
          const Text('거래유형', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: types.map((type) {
              final isSelected = ref.watch(historyTypeFilter) == type;
              return GestureDetector(
                onTap: () => ref.read(historyTypeFilter.notifier).state = type,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? null : Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : const Color(0xFF888888),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (brokers.isNotEmpty) ...[
            const SizedBox(height: 12),
            // 증권사
            const Text('증권사', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: brokerOptions.map((broker) {
                final isSelected = ref.watch(historyBrokerFilter) == broker;
                return GestureDetector(
                  onTap: () => ref.read(historyBrokerFilter.notifier).state = broker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? null : Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Text(
                      broker,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : const Color(0xFF888888),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketFilter() {
    const options = ['전체', '미국', '한국'];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
      children: options.map((option) {
        final isSelected = option == ref.watch(historyMarketFilter);
        return GestureDetector(
          onTap: () => ref.read(historyMarketFilter.notifier).state = option,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
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
    );
  }

  List<Transaction> _applyFilters(List<Transaction> txs, {
    required String marketFilter, required String accountFilter,
    required String typeFilter, required String brokerFilter,
  }) {
    return txs.where((tx) {
      if (marketFilter == '미국' && tx.market != Market.us) return false;
      if (marketFilter == '한국' &&
          tx.market != Market.krx &&
          tx.market != Market.kosdaq) return false;
      if (accountFilter != '전체' && tx.account != accountFilter) return false;
      if (typeFilter == '매수' && tx.type == TransactionType.sell) return false;
      if (typeFilter == '매도' && tx.type != TransactionType.sell) return false;
      if (brokerFilter != '전체' && tx.broker != brokerFilter) return false;
      return true;
    }).toList();
  }

  String _monthKey(String date) {
    if (date.length < 7) return date;
    final year = date.substring(0, 4);
    final month = date.substring(5, 7);
    return '$year년 $month월';
  }
}
