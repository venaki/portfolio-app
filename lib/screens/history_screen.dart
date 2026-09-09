import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../providers/filter_provider.dart';
import '../models/transaction.dart';
import '../models/other_asset.dart';
import '../widgets/transaction_card.dart';
import '../widgets/asset_card.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/edit_transaction_modal.dart';
import '../widgets/add_asset_modal.dart';
import '../widgets/edit_asset_modal.dart';
import '../widgets/form_fields.dart';
import 'portfolio_filters.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  DateTimeRange? _dates;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    ref.read(historyAccountFilter.notifier).state = '전체';
    ref.read(historyMarketFilter.notifier).state = '전체';
    ref.read(historyTypeFilter.notifier).state = '전체';
    ref.read(historyBrokerFilter.notifier).state = '전체';
    setState(() {
      _search.clear();
      _dates = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioProvider);
    final accounts = <String>{
      '전체',
      ...state.settings.accounts,
      ...state.transactions.map((tx) => tx.account),
      ...state.otherAssets.map((a) => a.account),
    };
    final brokers = <String>{
      '전체',
      ...state.settings.brokers,
      ...state.transactions
          .map((tx) => tx.broker)
          .where((value) => value.isNotEmpty),
    };
    final storedAccount = ref.watch(historyAccountFilter);
    final storedBroker = ref.watch(historyBrokerFilter);
    final account = accounts.contains(storedAccount) ? storedAccount : '전체';
    final broker = brokers.contains(storedBroker) ? storedBroker : '전체';
    final market = ref.watch(historyMarketFilter),
        type = ref.watch(historyTypeFilter);
    final txs = filterTransactions(
      state.transactions,
      account: account,
      broker: broker,
      market: market,
      type: type,
      query: _search.text,
      from: _dates?.start,
      to: _dates?.end,
    );
    final assets = filterAssets(
      state.otherAssets,
      account: account,
      broker: broker,
      market: market,
      type: type,
      query: _search.text,
      from: _dates?.start,
      to: _dates?.end,
    );
    final items = <({String key, Transaction? tx, OtherAsset? asset})>[
      ...txs.map((tx) => (key: tx.sortKey, tx: tx, asset: null)),
      ...assets.map((asset) => (key: asset.sortKey, tx: null, asset: asset)),
    ]..sort((a, b) => b.key.compareTo(a.key));
    final rows = <Object>[];
    String? month;
    for (final item in items) {
      final nextMonth = item.key.length >= 7
          ? item.key.substring(0, 7)
          : item.key;
      if (nextMonth != month) {
        month = nextMonth;
        rows.add(month);
      }
      rows.add(item.tx ?? item.asset!);
    }
    final accentColor = Theme.of(context).colorScheme.primary;
    final hPadding = MediaQuery.of(context).size.width >= 1024 ? 40.0 : 24.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: '내역 추가',
        onPressed: () => _showAddOptions(context),
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAccountFilter(accounts.toList(), account),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildFilterToggle(), _buildMarketFilter()],
                  ),
                  if (ref.watch(historyFilterExpanded)) ...[
                    const SizedBox(height: 12),
                    _buildExpandedFilters(
                      brokers.where((name) => name != '전체').toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (state.isLoading && rows.isEmpty)
                    const LinearProgressIndicator(),
                  if (!state.isLoading && rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          '거래내역이 없습니다',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 80),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, index) {
                final row = rows[index];
                if (row is String) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: 12,
                      top: index == 0 ? 4 : 12,
                    ),
                    child: Text(
                      _monthKey(row),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: Color(0xFF888888),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: row is Transaction
                      ? TransactionCard(
                          key: ValueKey(row.id),
                          transaction: row,
                          stockName: state.quotes[row.ticker]?.name,
                          onTap: () => showEditTransactionDialog(context, row),
                        )
                      : AssetCard(
                          key: ValueKey((row as OtherAsset).id),
                          asset: row,
                          onTap: () => showEditAssetDialog(context, row),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFilter(List<String> accounts, String selected) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: accounts.map((account) {
        final isSelected = account == selected;
        return GestureDetector(
          onTap: () => ref.read(historyAccountFilter.notifier).state = account,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFE5E5E5)),
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
    final hasActiveFilter =
        ref.watch(historyTypeFilter) != '전체' ||
        ref.watch(historyBrokerFilter) != '전체' ||
        _search.text.isNotEmpty ||
        _dates != null;
    return GestureDetector(
      onTap: () => ref.read(historyFilterExpanded.notifier).state = !ref.read(
        historyFilterExpanded,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasActiveFilter ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: hasActiveFilter
              ? null
              : Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ref.watch(historyFilterExpanded)
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
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
    const types = ['전체', '매수', '매도', '잔고 조정', '기타자산'];
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
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: recordInputDecoration(
              context,
              hint: '종목·자산명·메모 검색',
            ).copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final dates = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDateRange: _dates,
                  );
                  if (dates != null && mounted) {
                    setState(() => _dates = dates);
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  _dates == null
                      ? '기간 선택'
                      : '${_dates!.start.toIso8601String().substring(0, 10)} ~ ${_dates!.end.toIso8601String().substring(0, 10)}',
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('필터 초기화')),
            ],
          ),
          const SizedBox(height: 12),
          // 거래유형
          const Text(
            '거래유형',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: types.map((type) {
              final isSelected = ref.watch(historyTypeFilter) == type;
              return GestureDetector(
                onTap: () => ref.read(historyTypeFilter.notifier).state = type,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? null
                        : Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF888888),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (brokers.isNotEmpty) ...[
            const SizedBox(height: 12),
            // 증권사
            const Text(
              '증권사',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: brokerOptions.map((broker) {
                final isSelected = ref.watch(historyBrokerFilter) == broker;
                return GestureDetector(
                  onTap: () =>
                      ref.read(historyBrokerFilter.notifier).state = broker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Text(
                      broker,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF888888),
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
    const options = ['전체', '미국', '한국', '기타'];
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 2,
                    width: 20,
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.show_chart, color: accentColor),
                title: const Text('주식 거래 추가'),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddTransactionDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.account_balance_wallet, color: accentColor),
                title: const Text('기타 자산 추가'),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddAssetDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthKey(String date) {
    if (date.length < 7) return date;
    final year = date.substring(0, 4);
    final month = date.substring(5, 7);
    return '$year년 $month월';
  }
}
