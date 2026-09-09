import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import 'responsive_shell.dart';

class PortfolioStatusBanner extends ConsumerWidget {
  const PortfolioStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final hasIssues = state.dataIssues.isNotEmpty;
    final hasError = hasIssues || state.error != null;
    if (!hasError && !state.isSaving) return const SizedBox.shrink();
    final inset = MediaQuery.sizeOf(context).width >= ResponsiveShell.breakpoint
        ? 40.0
        : 24.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isSaving) const LinearProgressIndicator(minHeight: 2),
        if (hasError)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 16, inset, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFF777777),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasIssues
                              ? '데이터 확인이 필요합니다 · ${state.dataIssues.length}건'
                              : '작업을 완료하지 못했습니다',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (hasIssues)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '확인 전까지 저장이 제한됩니다.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(hasIssues ? '데이터 확인' : '오류 상세'),
                              content: SingleChildScrollView(
                                child: SelectableText(
                                  hasIssues
                                      ? state.dataIssues.join('\n\n')
                                      : state.error!,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '상세 보기',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '다시 불러오기',
                    icon: const Icon(Icons.refresh, size: 20),
                    color: const Color(0xFF777777),
                    onPressed: state.isLoading || state.isSaving
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(portfolioProvider.notifier)
                                  .loadAll();
                            } catch (_) {
                              // The provider retains the visible error.
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
