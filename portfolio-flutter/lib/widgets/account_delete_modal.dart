import 'package:flutter/material.dart';

class AccountDeleteModal extends StatelessWidget {
  final String accountName;
  final bool isBlocked;
  final int transactionCount;
  final VoidCallback? onConfirm;

  const AccountDeleteModal({
    super.key,
    required this.accountName,
    required this.isBlocked,
    this.transactionCount = 0,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBlocked ? '삭제 불가' : '명의 삭제',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isBlocked
                  ? '\'$accountName\' 명의에 $transactionCount건의 거래내역이 있어 삭제할 수 없습니다.'
                  : '\'$accountName\' 명의를 삭제하시겠습니까?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            if (isBlocked) ...[
              const SizedBox(height: 4),
              const Text(
                '거래내역을 먼저 삭제해주세요.',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ],
            const SizedBox(height: 20),
            if (isBlocked)
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        onConfirm?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE07B54),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
