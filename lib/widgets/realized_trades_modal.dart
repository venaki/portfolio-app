import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/holdings_engine.dart';
import '../providers/portfolio_provider.dart';
import '../utils/format.dart';
import 'edit_transaction_modal.dart';

Future<void> showRealizedTradesDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _RealizedTradesDialog());

class _RealizedTradesDialog extends ConsumerWidget {
  const _RealizedTradesDialog();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = replayPortfolio(ref.watch(portfolioProvider).transactions);
    final trades = result.realizedTrades.reversed.toList();
    final total = trades.fold<double>(0, (sum, trade) => sum + trade.profitKRW);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '전체 실현손익',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '합계 ${formatKRW(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('매도 완료 종목을 포함합니다. 수수료·세금은 포함하지 않습니다.'),
              ),
              if (result.issues.isNotEmpty)
                const Text('원장에 오류가 있어 유효한 거래만 표시합니다.'),
              if (trades.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('실현손익 내역이 없습니다.'),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: trades.length,
                  itemBuilder: (_, index) {
                    final trade = trades[index];
                    final tx = trade.transaction;
                    return ListTile(
                      title: Text('${tx.ticker} · ${tx.account}'),
                      subtitle: Text(
                        '${tx.date} · ${tx.broker} · ${formatShares(tx.shares)}주',
                      ),
                      trailing: Text(formatKRW(trade.profitKRW)),
                      onTap: () => showEditTransactionDialog(context, tx),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
