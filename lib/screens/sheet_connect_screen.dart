import '../widgets/form_fields.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/portfolio_provider.dart';

String? extractSpreadsheetId(String input) {
  final trimmed = input.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host == 'docs.google.com') {
    final match = RegExp(
      r'^/spreadsheets/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(uri.path);
    if (match != null) return match.group(1);
  }
  return RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed) ? trimmed : null;
}

class SheetConnectScreen extends ConsumerStatefulWidget {
  const SheetConnectScreen({super.key});
  @override
  ConsumerState<SheetConnectScreen> createState() => _SheetConnectScreenState();
}

class _SheetConnectScreenState extends ConsumerState<SheetConnectScreen> {
  bool _busy = false;
  String? _error;
  final _url = TextEditingController();
  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '연결 작업 실패: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishConnection(String id) async {
    await saveSpreadsheetId(id);
    if (!mounted) return;
    ref.invalidate(spreadsheetIdProvider);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _createNew() => _run(() async {
    final id = await ref.read(portfolioProvider.notifier).createAndConnect();
    await _finishConnection(id);
  });
  Future<void> _connect(String id) async {
    await ref.read(portfolioProvider.notifier).connect(id);
    await _finishConnection(id);
  }

  Future<void> _connectUrl() => _run(() async {
    final id = extractSpreadsheetId(_url.text);
    if (id == null) {
      throw const FormatException('올바른 Google Sheets URL 또는 시트 ID를 입력해주세요.');
    }
    await _connect(id);
  });
  Future<void> _pickSheet() => _run(() async {
    final auth = ref.read(authServiceProvider);
    if (!await auth.requestDriveScope()) {
      throw Exception('Drive 목록 권한을 받지 못했습니다. 아래 URL 입력으로 연결할 수 있습니다.');
    }
    final headers = await auth.getAuthHeadersInteractive();
    final files = <Map<String, dynamic>>[];
    String? nextToken;
    do {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q':
            "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        'orderBy': 'modifiedTime desc',
        'pageSize': '100',
        'fields': 'nextPageToken,files(id,name,modifiedTime)',
        if (nextToken != null) 'pageToken': nextToken,
      });
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception(
          '시트 목록을 불러오지 못했습니다 (${response.statusCode}). URL로 연결할 수 있습니다.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      files.addAll(
        (data['files'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      );
      nextToken = data['nextPageToken'] as String?;
    } while (nextToken != null && nextToken.isNotEmpty);
    if (!mounted) return;
    if (files.isEmpty) {
      throw Exception('연결할 스프레드시트가 없습니다. 새 시트를 생성하거나 URL을 입력해주세요.');
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SheetPickerDialog(files: files),
    );
    if (selected != null && mounted) await _connect(selected['id'] as String);
  });
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: Navigator.canPop(context)
            ? AppBar(
                backgroundColor: const Color(0xFFFAFAFA),
                elevation: 0,
                title: const Text('스프레드시트 연결', style: TextStyle(fontSize: 14)),
              )
            : null,
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo area
                  const Column(
                    children: [
                      Icon(
                        Icons.table_chart,
                        size: 40,
                        color: Color(0xFF0D6E6E),
                      ),
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
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),

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
                          onTap: _busy ? null : _createNew,
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
                                  child: _busy
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                          onTap: _busy ? null : _pickSheet,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Google Sheets URL 또는 ID',
                      style: recordLabelStyle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _url,
                    enabled: !_busy,
                    onSubmitted: (_) => _connectUrl(),
                    style: const TextStyle(fontSize: 14),
                    decoration: recordInputDecoration(
                      context,
                      hint: 'https://docs.google.com/spreadsheets/...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: recordButtonStyle(context),
                      onPressed: _busy ? null : _connectUrl,
                      child: const Text('URL로 연결'),
                    ),
                  ),
                ],
              ),
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
                  const Icon(
                    Icons.description,
                    size: 20,
                    color: Color(0xFF0D6E6E),
                  ),
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
                    fontSize: 13,
                    color: Color(0xFFAAAAAA),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFFAAAAAA),
                  ),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
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
                        final date = _formatDate(
                          file['modifiedTime'] as String?,
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.pop(context, file),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.table_chart,
                                  size: 20,
                                  color: Color(0xFF0D6E6E),
                                ),
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
