import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import 'ticker_search.dart';

/// Shows the add-transaction dialog (centered on web/desktop).
Future<void> showAddTransactionDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const Center(child: AddTransactionModal()),
  );
}

class AddTransactionModal extends ConsumerStatefulWidget {
  const AddTransactionModal({super.key});

  @override
  ConsumerState<AddTransactionModal> createState() =>
      _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _rateController = TextEditingController();
  final _dateController = TextEditingController();
  final _memoController = TextEditingController();

  TransactionType _type = TransactionType.buy;
  Market _market = Market.us;
  String _account = '';
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  String _ticker = '';
  String _tickerName = '';

  Currency get _currency => _market == Market.us ? Currency.usd : Currency.krw;

  @override
  void initState() {
    super.initState();
    final accounts = ref.read(portfolioProvider).settings.accounts;
    if (accounts.isNotEmpty) _account = accounts.first;
    _dateController.text = _date.toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _rateController.dispose();
    _dateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_account.isEmpty) return;

    setState(() => _isSaving = true);

    final tx = Transaction(
      id: const Uuid().v4(),
      date: _date.toIso8601String().substring(0, 10),
      account: _account,
      type: _type,
      ticker: _ticker.isEmpty ? '' : _ticker.toUpperCase(),
      market: _market,
      name: _tickerName.isEmpty ? _nameController.text.trim() : _tickerName,
      shares: double.tryParse(_sharesController.text) ?? 0,
      price: double.tryParse(_priceController.text) ?? 0,
      currency: _currency,
      exchangeRate: double.tryParse(_rateController.text) ?? 0,
      memo: _memoController.text.trim(),
    );

    try {
      await ref.read(portfolioProvider.notifier).addTransaction(tx);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<TickerSearchResult> _getExistingTickers() {
    final portfolio = ref.read(portfolioProvider);
    final isUS = _market == Market.us;
    final seen = <String>{};
    final results = <TickerSearchResult>[];
    for (final tx in portfolio.transactions) {
      final txIsUS = tx.market == Market.us;
      if (txIsUS != isUS) continue;
      if (seen.add(tx.ticker)) {
        final quote = portfolio.quotes[tx.ticker];
        final name = quote?.name ?? tx.name;
        final exchange = tx.market == Market.us ? 'US'
            : tx.market == Market.krx ? 'KRX'
            : tx.market == Market.kosdaq ? 'KOSDAQ' : '';
        results.add(TickerSearchResult(ticker: tx.ticker, name: name, exchange: exchange));
      }
    }
    return results;
  }

  void _onTickerSelected(TickerSearchResult result) {
    setState(() {
      _ticker = result.ticker;
      _tickerName = result.name;
      _nameController.text = result.name;
      // Infer market from exchange
      final ex = result.exchange.toUpperCase();
      if (ex.contains('KRX') || ex.contains('KOSDAQ') || ex.contains('KSE') || ex.contains('KOREA')) {
        _market = ex.contains('KOSDAQ') ? Market.kosdaq : Market.krx;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(portfolioProvider).settings.accounts;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '거래 추가',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close,
                          size: 24, color: Color(0xFF888888)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 자산유형
                _buildLabel('자산유형'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildChip('미국',
                        isActive: _market == Market.us,
                        accentColor: accentColor,
                        onTap: () => setState(() => _market = Market.us)),
                    const SizedBox(width: 8),
                    _buildChip('한국',
                        isActive: _market != Market.us,
                        accentColor: accentColor,
                        onTap: () => setState(() => _market = Market.krx)),
                  ],
                ),
                const SizedBox(height: 16),

                // 명의
                _buildLabel('명의'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts
                      .map((a) => _buildChip(a,
                          isActive: _account == a,
                          accentColor: accentColor,
                          onTap: () => setState(() => _account = a)))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // 종목코드 (TickerSearch)
                _buildLabel('종목코드'),
                const SizedBox(height: 6),
                TickerSearch(
                  hint: _market == Market.us ? '예: TSLA' : '예: 005930',
                  existingTickers: _getExistingTickers(),
                  onSelected: _onTickerSelected,
                  onManualInput: (value) {
                    setState(() {
                      _ticker = value;
                      if (_tickerName.isEmpty) _nameController.text = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 거래유형
                _buildLabel('거래유형'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildChip('매수',
                        isActive: _type == TransactionType.buy,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _type = TransactionType.buy)),
                    const SizedBox(width: 8),
                    _buildChip('매도',
                        isActive: _type == TransactionType.sell,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _type = TransactionType.sell)),
                  ],
                ),
                const SizedBox(height: 16),

                // 수량
                _buildLabel('수량'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _sharesController,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),

                // 체결가
                _buildLabel(
                    '체결가 (${_currency == Currency.usd ? "USD" : "KRW"})'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),

                // 환율 (USD only)
                if (_currency == Currency.usd) ...[
                  _buildLabel('환율 (KRW/USD)'),
                  const SizedBox(height: 6),
                  _buildInput(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // 날짜
                _buildLabel('날짜'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                        _dateController.text =
                            picked.toIso8601String().substring(0, 10);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: _buildInput(
                      controller: _dateController,
                      hint: 'YYYY-MM-DD',
                      accentColor: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 메모
                _buildLabel('메모 (선택)'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _memoController,
                  maxLines: 2,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '거래 추가',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required bool isActive,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? accentColor : const Color(0xFFE5E5E5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    TextEditingController? controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    required Color accentColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
          borderSide: BorderSide(color: accentColor),
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
    );
  }
}
