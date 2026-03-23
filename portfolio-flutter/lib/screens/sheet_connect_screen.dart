import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';

class SheetConnectScreen extends ConsumerStatefulWidget {
  const SheetConnectScreen({super.key});

  @override
  ConsumerState<SheetConnectScreen> createState() => _SheetConnectScreenState();
}

class _SheetConnectScreenState extends ConsumerState<SheetConnectScreen> {
  bool _isCreating = false;

  Future<void> _createNew() async {
    setState(() => _isCreating = true);
    try {
      final id = await ref.read(portfolioProvider.notifier).createAndConnect();
      await saveSpreadsheetId(id);
      if (mounted) {
        ref.invalidate(spreadsheetIdProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _showConnectDialog() async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스프레드시트 URL 입력'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://docs.google.com/spreadsheets/d/...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            child: const Text('연결'),
          ),
        ],
      ),
    );
    urlController.dispose();

    if (result == null || result.isEmpty) return;
    await _connectExisting(result);
  }

  Future<void> _connectExisting(String url) async {
    final id = _extractSpreadsheetId(url);
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 Google Sheets URL을 입력해주세요')),
        );
      }
      return;
    }

    try {
      await saveSpreadsheetId(id);
      await ref.read(portfolioProvider.notifier).connect(id);
      if (mounted) {
        ref.invalidate(spreadsheetIdProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
  }

  String? _extractSpreadsheetId(String input) {
    final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(input);
    if (match != null) return match.group(1);
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(input)) return input;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo area
              const Column(
                children: [
                  Icon(Icons.table_chart, size: 40, color: Color(0xFF0D6E6E)),
                  SizedBox(height: 8),
                  Text(
                    '스프레드시트 연결',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '데이터를 저장할 Google Sheets를 선택하세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Options card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  children: [
                    // Option 1: Create new
                    GestureDetector(
                      onTap: _isCreating ? null : _createNew,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _isCreating
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0D6E6E),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.add,
                                        size: 20,
                                        color: Color(0xFF0D6E6E),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '새 스프레드시트 생성',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '빈 Portfolio DB를 자동으로 만듭니다',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFFAAAAAA),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: const Color(0xFFF0F0F0),
                    ),

                    // Option 2: Connect existing
                    GestureDetector(
                      onTap: _showConnectDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.link,
                                  size: 20,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '기존 스프레드시트 연결',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Google Drive에서 시트를 선택합니다',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFFAAAAAA),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
