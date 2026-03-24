import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
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

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final accentColor = Theme.of(context).colorScheme.primary;

    if (portfolio.isLoading && portfolio.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = ['전체', ...portfolio.settings.accounts];
    final filtered = _applyFilters(portfolio.transactions);
    filtered.sort((a, b) => b.date.compareTo(a.date));

    final grouped = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = _monthKey(tx.date);
      (grouped[key] ??= []).add(tx);
    }

    final isWide = MediaQuery.of(context).size.width >= 768;
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
          const SizedBox(height: 12),

          // Row 2: Type pills (좌) + Market underline (우)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTypePills(),
              _buildMarketFilter(),
            ],
          ),
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
        final isSelected = account == _accountFilter;
        return GestureDetector(
          onTap: () => setState(() => _accountFilter = account),
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

  Widget _buildTypePills() {
    const types = ['전체', '매수', '매도'];
    return Row(
      children: types.map((type) {
        final isSelected = _typeFilter == type;
        return GestureDetector(
          onTap: () => setState(() => _typeFilter = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? null : Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Text(
              type,
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

  Widget _buildMarketFilter() {
    const options = ['전체', '미국', '한국'];
    return Row(
      children: options.map((option) {
        final isSelected = option == _marketFilter;
        return GestureDetector(
          onTap: () => setState(() => _marketFilter = option),
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
    );
  }

  List<Transaction> _applyFilters(List<Transaction> txs) {
    return txs.where((tx) {
      if (_marketFilter == '미국' && tx.market != Market.us) return false;
      if (_marketFilter == '한국' &&
          tx.market != Market.krx &&
          tx.market != Market.kosdaq) return false;
      if (_accountFilter != '전체' && tx.account != _accountFilter) return false;
      if (_typeFilter == '매수' && tx.type == TransactionType.sell) return false;
      if (_typeFilter == '매도' && tx.type != TransactionType.sell) return false;
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
