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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: '내역 추가',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormChoices(
                    label: '명의',
                    options: {for (final name in accounts) name: name},
                    value: account,
                    onChanged: (value) =>
                        ref.read(historyAccountFilter.notifier).state = value,
                  ),
                  FormChoices(
                    label: '시장',
                    options: const {
                      '전체': '전체',
                      '미국': '미국',
                      '한국': '한국',
                      '기타': '기타',
                    },
                    value: market,
                    onChanged: (value) =>
                        ref.read(historyMarketFilter.notifier).state = value,
                  ),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '종목·자산명·메모 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
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
                      TextButton(
                        onPressed: _reset,
                        child: const Text('필터 초기화'),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('거래 유형·증권사'),
                    children: [
                      FormChoices(
                        label: '거래 유형',
                        options: const {
                          '전체': '전체',
                          '매수': '매수',
                          '매도': '매도',
                          '잔고 조정': '잔고 조정',
                          '기타자산': '기타자산',
                        },
                        value: type,
                        onChanged: (value) =>
                            ref.read(historyTypeFilter.notifier).state = value,
                      ),
                      FormChoices(
                        label: '증권사 (선택 시 주식 거래만 표시)',
                        options: {for (final name in brokers) name: name},
                        value: broker,
                        onChanged: (value) =>
                            ref.read(historyBrokerFilter.notifier).state =
                                value,
                      ),
                    ],
                  ),
                  if (state.isLoading && rows.isEmpty)
                    const LinearProgressIndicator(),
                  if (!state.isLoading && rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '조건에 맞는 내역이 없습니다.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, index) {
                final row = rows[index];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(row),
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

  void _add() => showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('주식 거래 추가'),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddTransactionDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('기타자산 내역 추가'),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddAssetDialog(context);
            },
          ),
        ],
      ),
    ),
  );
}
