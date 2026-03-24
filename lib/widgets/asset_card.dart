import 'package:flutter/material.dart';
import '../models/other_asset.dart';
import '../models/transaction.dart';
import '../utils/format.dart';

class AssetCard extends StatelessWidget {
  final OtherAsset asset;
  final VoidCallback? onTap;

  const AssetCard({
    super.key,
    required this.asset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLoan = asset.category == AssetCategory.loan;
    final isUSD = asset.currency == Currency.usd;
    final displayValue = isLoan && asset.value > 0 ? -asset.value : asset.value;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            // Left: name + tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildTag(
                        asset.account,
                        bgColor: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
                        textColor: const Color(0xFF0D6E6E),
                      ),
                      _buildTag(
                        asset.categoryLabel,
                        bgColor: const Color(0xFFF0F0F0),
                        textColor: const Color(0xFF888888),
                      ),
                      _buildTag(
                        isUSD ? 'USD' : 'KRW',
                        bgColor: const Color(0xFFF0F0F0),
                        textColor: const Color(0xFF888888),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right: amount
            Text(
              isUSD ? formatUSD(displayValue) : formatKRW(displayValue),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isLoan ? const Color(0xFFE07B54) : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, {required Color bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
