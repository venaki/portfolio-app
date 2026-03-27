import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
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
        if (Navigator.canPop(context)) Navigator.pop(context);
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

  Future<void> _showSheetPicker() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Drive 스코프 추가 요청
      final granted = await ref.read(authServiceProvider).requestDriveScope();
      if (!granted) {
        if (mounted) Navigator.pop(context);
        _showUrlInputDialog();
        return;
      }

      final headers = await ref.read(authServiceProvider).getAuthHeadersInteractive();
      final res = await http.get(
        Uri.parse(
          "https://www.googleapis.com/drive/v3/files"
          "?q=mimeType%3D'application%2Fvnd.google-apps.spreadsheet'"
          "&orderBy=modifiedTime+desc"
          "&pageSize=30"
          "&fields=files(id%2Cname%2CmodifiedTime)",
        ),
        headers: headers,
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (res.statusCode != 200) {
        _showUrlInputDialog();
        return;
      }

      final data = jsonDecode(res.body);
      final files = (data['files'] as List?) ?? [];

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive에 스프레드시트가 없습니다')),
        );
        return;
      }

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _SheetPickerDialog(
          files: files.cast<Map<String, dynamic>>(),
        ),
      );

      if (selected != null) {
        await _connectById(selected['id'] as String);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading if still showing
        _showUrlInputDialog(); // fallback
      }
    }
  }

  Future<void> _showUrlInputDialog() async {
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
    await _connectById(id);
  }

  Future<void> _connectById(String id) async {
    try {
      await saveSpreadsheetId(id);
      await ref.read(portfolioProvider.notifier).connect(id);
      if (mounted) {
        ref.invalidate(spreadsheetIdProvider);
        if (Navigator.canPop(context)) Navigator.pop(context);
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
    final match =
        RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(input);
    if (match != null) return match.group(1);
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(input)) return input;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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

                    // Option 2: Connect existing (now opens sheet picker)
                    GestureDetector(
                      onTap: _showSheetPicker,
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
                                  Icons.folder_open,
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
      ),
    );
  }
}

class _SheetPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> files;

  const _SheetPickerDialog({required this.files});

  @override
  State<_SheetPickerDialog> createState() => _SheetPickerDialogState();
}

class _SheetPickerDialogState extends State<_SheetPickerDialog> {
  String _query = '';

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.files;
    final q = _query.toLowerCase();
    return widget.files
        .where((f) => (f['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy.MM.dd HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.description,
                      size: 20, color: Color(0xFF0D6E6E)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '스프레드시트 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: '검색...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFFAAAAAA)),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFFAAAAAA)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

            // List
            Flexible(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '일치하는 시트가 없습니다',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF888888)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Color(0xFFF0F0F0),
                      ),
                      itemBuilder: (context, i) {
                        final file = filtered[i];
                        final name = file['name'] as String? ?? '';
                        final date = _formatDate(file['modifiedTime'] as String?);

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.pop(context, file),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.table_chart,
                                    size: 20, color: Color(0xFF0D6E6E)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (date.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          date,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
