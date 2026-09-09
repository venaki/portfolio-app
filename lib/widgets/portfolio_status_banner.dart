import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';

class PortfolioStatusBanner extends ConsumerWidget {
  const PortfolioStatusBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final message = state.dataIssues.isNotEmpty
        ? '시트 원본에서 다음 오류를 수정한 뒤 다시 불러와 주세요. 오류가 해결될 때까지 저장을 제한합니다.\n${state.dataIssues.take(4).join('\n')}'
        : state.error;
    if (message == null && !state.isSaving) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isSaving) const LinearProgressIndicator(),
        if (message != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading || state.isSaving
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(portfolioProvider.notifier)
                                  .loadAll();
                            } catch (_) {
                              /* The provider retains the visible error. */
                            }
                          },
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
