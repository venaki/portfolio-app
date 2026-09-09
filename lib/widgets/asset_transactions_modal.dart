import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../providers/portfolio_provider.dart';
import 'asset_card.dart';
import 'asset_form.dart';
import 'edit_asset_modal.dart';

Future<void> showAssetTransactionsDialog(
  BuildContext context,
  ConsolidatedAsset asset,
) => showDialog(
  context: context,
  builder: (_) => _AssetTransactionsDialog(asset: asset),
);

class _AssetTransactionsDialog extends ConsumerWidget {
  const _AssetTransactionsDialog({required this.asset});
  final ConsolidatedAsset asset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final records =
        state.otherAssets
            .where(
              (record) =>
                  record.account == asset.account &&
                  record.name == asset.name &&
                  record.category == asset.category &&
                  record.currency == asset.currency,
            )
            .toList()
          ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${asset.name} 내역',
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
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AssetCard(
                      asset: records[index],
                      onTap: () => showEditAssetDialog(context, records[index]),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AssetForm(
                    initialAccount: asset.account,
                    initialName: asset.name,
                    initialCategory: asset.category,
                    initialCurrency: asset.currency,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('입출금·상환 내역 추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
