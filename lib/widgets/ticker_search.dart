import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class TickerSearchResult {
  final String ticker;
  final String name;
  final String exchange;
  const TickerSearchResult({
    required this.ticker,
    required this.name,
    required this.exchange,
  });
}

class TickerSearch extends StatefulWidget {
  final String? initialValue;
  final bool readOnly;
  final ValueChanged<TickerSearchResult>? onSelected;
  final ValueChanged<String>? onManualInput;
  final String hint;
  /// 한국 주식 모드: 종목명으로 검색하고, 선택 시 종목명 표시 + 코드 자동 세팅
  final bool isKorean;
  /// 기존 거래 종목 목록 (포커스 시 드롭다운 표시)
  final List<TickerSearchResult> existingTickers;

  const TickerSearch({
    super.key,
    this.initialValue,
    this.readOnly = false,
    this.onSelected,
    this.onManualInput,
    this.hint = '예: TSLA',
    this.isKorean = false,
    this.existingTickers = const [],
  });

  @override
  State<TickerSearch> createState() => _TickerSearchState();
}

class _TickerSearchState extends State<TickerSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<TickerSearchResult> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showExistingTickers(_controller.text.trim());
    } else {
      // 딜레이: 드롭다운 항목 탭이 먼저 처리되도록
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _showExistingTickers(String query) {
    if (widget.existingTickers.isEmpty) return;
    final q = query.toUpperCase();
    final filtered = q.isEmpty
        ? widget.existingTickers
        : widget.existingTickers.where((t) =>
            t.ticker.toUpperCase().contains(q) ||
            t.name.toUpperCase().contains(q)).toList();
    if (filtered.isNotEmpty) {
      _results = filtered;
      _showOverlay();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (widget.isKorean) {
      // 한국주식: 종목명 그대로 검색, 대문자 변환 안 함
      widget.onManualInput?.call(trimmed);
      _showExistingTickers(trimmed);
    } else {
      // 미국주식: 대문자 변환 + 부모에게 값 전달
      final upper = trimmed.toUpperCase();
      if (_controller.text != upper) {
        final offset = _controller.selection.baseOffset;
        _controller.text = upper;
        _controller.selection = TextSelection.collapsed(
          offset: offset.clamp(0, upper.length),
        );
      }
      widget.onManualInput?.call(upper);
      _showExistingTickers(upper);
    }

    if (trimmed.length < 2) {
      if (widget.existingTickers.isEmpty) _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$corsProxyBase/search?q=$query');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _results = data
            .take(5)
            .map((item) => TickerSearchResult(
                  ticker: item['ticker'] ?? item['symbol'] ?? '',
                  name: item['name'] ?? '',
                  exchange: item['exchange'] ?? '',
                ))
            .toList();
        if (_results.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      } else {
        _removeOverlay();
      }
    } catch (_) {
      // Network failure: hide dropdown, allow manual input
      _removeOverlay();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return InkWell(
                    onTap: () => _selectResult(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            widget.isKorean ? r.name : r.ticker,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.isKorean ? r.ticker : r.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r.exchange,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectResult(TickerSearchResult result) {
    // 한국주식: 종목명 표시, 미국주식: 티커 표시
    _controller.text = widget.isKorean ? result.name : result.ticker.toUpperCase();
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelected?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        onChanged: widget.readOnly ? null : _onChanged,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0D6E6E),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(maxWidth: 40, maxHeight: 40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0D6E6E)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
          isDense: true,
        ),
        validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
      ),
    );
  }
}
