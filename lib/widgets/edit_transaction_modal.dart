import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import 'transaction_delete_modal.dart';
import 'ticker_search.dart';

/// Shows the edit-transaction dialog.
Future<void> showEditTransactionDialog(
    BuildContext context, Transaction transaction) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Center(child: EditTransactionModal(transaction: transaction)),
  );
}

class EditTransactionModal extends ConsumerStatefulWidget {
  final Transaction transaction;
  const EditTransactionModal({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionModal> createState() =>
      _EditTransactionModalState();
}

class _EditTransactionModalState extends ConsumerState<EditTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _rateController = TextEditingController();
  final _dateController = TextEditingController();
  final _memoController = TextEditingController();

  late TransactionType _type;
  late Market _market;
  late String _account;
  late String _broker;
  late DateTime _date;
  late String _ticker;
  late String _tickerName;
  bool _isSaving = false;

  Currency get _currency => _market == Market.us ? Currency.usd : Currency.krw;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx.type;
    _market = tx.market;
    _account = tx.account;
    _broker = tx.broker;
    _ticker = tx.ticker;
    _tickerName = tx.name;
    _date = DateTime.tryParse(tx.date) ?? DateTime.now();
    _sharesController.text = tx.shares.toString();
    _priceController.text = tx.price.toString();
    _rateController.text = tx.exchangeRate.toString();
    _dateController.text = tx.date;
    _memoController.text = tx.memo;
  }

  @override
  void dispose() {
    _sharesController.dispose();
    _priceController.dispose();
    _rateController.dispose();
    _dateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final tx = Transaction(
      id: widget.transaction.id,
      date: _date.toIso8601String().substring(0, 10),
      account: _account,
      type: _type,
      ticker: _ticker.toUpperCase(),
      market: _market,
      name: _tickerName,
      shares: double.tryParse(_sharesController.text) ?? 0,
      price: double.tryParse(_priceController.text) ?? 0,
      currency: _currency,
      exchangeRate: double.tryParse(_rateController.text) ?? 0,
      broker: _broker,
      memo: _memoController.text.trim(),
    );

    try {
      await ref.read(portfolioProvider.notifier).updateTransaction(tx);
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

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => TransactionDeleteModal(
        onConfirm: () async {
          try {
            await ref
                .read(portfolioProvider.notifier)
                .deleteTransaction(widget.transaction.id);
            if (mounted) Navigator.of(context).pop(); // close edit modal
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('삭제 실패: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(portfolioProvider).settings;
    final accounts = settings.accounts;
    final brokers = settings.brokers;
    final tx = widget.transaction;
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
                      '거래 수정',
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

                // 증권사
                if (brokers.isNotEmpty) ...[
                  _buildLabel('증권사'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: brokers
                        .map((b) => _buildChip(b,
                            isActive: _broker == b,
                            accentColor: accentColor,
                            onTap: () => setState(() => _broker = b)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 종목코드
                _buildLabel(_market == Market.us ? '티커' : '종목명'),
                const SizedBox(height: 6),
                TickerSearch(
                  initialValue: _market == Market.us ? tx.ticker : (tx.name.isNotEmpty ? tx.name : tx.ticker),
                  hint: _market == Market.us ? '예: TSLA' : '예: 삼성전자',
                  isKorean: _market != Market.us,
                  onSelected: (result) {
                    setState(() {
                      _ticker = result.ticker;
                      _tickerName = result.name;
                      final ex = result.exchange.toUpperCase();
                      if (ex.contains('KRX') || ex.contains('KOSDAQ') || ex.contains('KSE') || ex.contains('KOREA')) {
                        _market = ex.contains('KOSDAQ') ? Market.kosdaq : Market.krx;
                      }
                    });
                  },
                  onManualInput: (value) {
                    setState(() {
                      _ticker = value;
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

                // Bottom buttons: 삭제 + 저장
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showDeleteConfirm,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
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
                                  '저장',
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
