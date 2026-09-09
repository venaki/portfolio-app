import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import 'form_fields.dart';
import 'ticker_search.dart';

String? validateTicker(String? value, Market market) {
  final ticker = value?.trim().toUpperCase() ?? '';
  if (ticker.isEmpty) return '종목을 입력해주세요';
  if (market == Market.us) {
    return RegExp(r'^[A-Z][A-Z0-9.\-]{0,14}$').hasMatch(ticker)
        ? null
        : '올바른 미국 종목 티커를 입력해주세요';
  }
  return RegExp(r'^\d{6}$').hasMatch(ticker)
      ? null
      : '검색 결과를 선택하거나 6자리 종목코드를 입력해주세요';
}

class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({super.key, this.transaction});
  final Transaction? transaction;
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _shares = TextEditingController(),
      _price = TextEditingController(),
      _rate = TextEditingController();
  final _memo = TextEditingController(),
      _dateText = TextEditingController(),
      _timeText = TextEditingController();
  late Market _market;
  late TransactionType _type;
  late DateTime _date;
  late TimeOfDay _time;
  String _account = '', _broker = '', _ticker = '', _name = '';
  String? _error;
  bool _busy = false;
  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    final state = ref.read(portfolioProvider);
    _market = tx?.market ?? Market.us;
    _type = tx?.type ?? TransactionType.buy;
    _account = tx?.account ?? state.settings.accounts.firstOrNull ?? '';
    _broker = tx?.broker ?? state.settings.brokers.firstOrNull ?? '';
    _ticker = tx?.ticker ?? '';
    _name = tx?.name ?? '';
    _date = DateTime.tryParse(tx?.date ?? '') ?? DateTime.now();
    final parts = (tx?.time ?? '').split(':');
    _time = TimeOfDay(
      hour: (int.tryParse(parts.first) ?? TimeOfDay.now().hour).clamp(0, 23),
      minute:
          (int.tryParse(parts.length > 1 ? parts[1] : '') ??
                  TimeOfDay.now().minute)
              .clamp(0, 59),
    );
    _shares.text = tx?.shares.toString() ?? '';
    _price.text = tx?.price.toString() ?? '';
    _rate.text = tx?.exchangeRate.toString() ?? '';
    _memo.text = tx?.memo ?? '';
    _updateDateTexts();
  }

  void _updateDateTexts() {
    _dateText.text = _date.toIso8601String().substring(0, 10);
    _timeText.text =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final controller in [
      _shares,
      _price,
      _rate,
      _memo,
      _dateText,
      _timeText,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        !ref.read(portfolioProvider).canWrite ||
        !_form.currentState!.validate()) {
      return;
    }
    if (_account.isEmpty) {
      setState(() => _error = '설정에서 명의를 먼저 등록해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tx = Transaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        date: _dateText.text,
        time: _timeText.text,
        account: _account,
        broker: _broker,
        type: _type,
        ticker: _ticker.trim().toUpperCase(),
        market: _market,
        name: _name.isEmpty ? _ticker.trim().toUpperCase() : _name,
        shares: parseAmount(_shares.text)!,
        price: parseAmount(_price.text)!,
        currency: _market == Market.us ? Currency.usd : Currency.krw,
        exchangeRate: _market == Market.us ? parseAmount(_rate.text)! : 1,
        memo: _memo.text.trim(),
      );
      final notifier = ref.read(portfolioProvider.notifier);
      if (_editing) {
        await notifier.updateTransaction(tx);
      } else {
        await notifier.addTransaction(tx);
      }
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '저장 실패: $error';
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_busy || !await confirmDelete(context, '거래 삭제') || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(portfolioProvider.notifier)
          .deleteTransaction(widget.transaction!.id);
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '삭제 실패: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioProvider);
    final canWrite = state.canWrite;
    final accounts = {
      ...state.settings.accounts,
      if (_account.isNotEmpty) _account,
    };
    final brokers = {
      ...state.settings.brokers,
      if (_broker.isNotEmpty) _broker,
    };
    final existing = <String, TickerSearchResult>{};
    for (final tx in state.transactions) {
      if ((tx.market == Market.us) != (_market == Market.us)) continue;
      existing[tx.ticker] = TickerSearchResult(
        ticker: tx.ticker,
        name: state.quotes[tx.ticker]?.name ?? tx.name,
        exchange: tx.market.toSheetValue(),
      );
    }
    return RecordFormDialog(
      title: _editing ? '거래 수정' : '거래 추가',
      busy: _busy,
      onClose: () => Navigator.pop(context),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canWrite && !_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('현재 연결·작업 상태를 확인한 후 저장할 수 있습니다.'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('설정에서 명의를 먼저 등록해주세요.'),
              ),
            FormChoices(
              label: '시장',
              options: const {
                Market.us: '미국',
                Market.krx: 'KRX',
                Market.kosdaq: 'KOSDAQ',
              },
              value: _market,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() {
                _market = value;
                _ticker = '';
                _name = '';
              }),
            ),
            FormChoices(
              label: '명의',
              options: {for (final account in accounts) account: account},
              value: _account,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _account = value),
            ),
            FormChoices(
              label: '증권사',
              options: {
                '': '미지정',
                for (final broker in brokers) broker: broker,
              },
              value: _broker,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _broker = value),
            ),
            const Text('종목'),
            const SizedBox(height: 8),
            TickerSearch(
              key: ValueKey(_market),
              initialValue: _ticker,
              isKorean: _market != Market.us,
              readOnly: _busy || !canWrite,
              existingTickers: existing.values.toList(),
              validator: (_) => validateTicker(_ticker, _market),
              onManualInput: (value) {
                _ticker = value;
                _name = '';
              },
              onSelected: (result) => setState(() {
                _ticker = result.ticker;
                _name = result.name;
                if (_market != Market.us) {
                  _market = result.exchange.toUpperCase().contains('KOSDAQ')
                      ? Market.kosdaq
                      : Market.krx;
                }
              }),
            ),
            const SizedBox(height: 16),
            FormChoices(
              label: '거래 유형',
              options: const {
                TransactionType.buy: '매수',
                TransactionType.sell: '매도',
                TransactionType.openingBalance: '기초 잔고',
                TransactionType.adjustment: '잔고 조정',
              },
              value: _type,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _type = value),
            ),
            FormInput(
              label: '수량',
              controller: _shares,
              numeric: true,
              enabled: !_busy && canWrite,
              validator: validateAmount,
            ),
            FormInput(
              label: '체결가 (${_market == Market.us ? 'USD' : 'KRW'})',
              controller: _price,
              numeric: true,
              enabled: !_busy && canWrite,
              validator: validateAmount,
            ),
            if (_market == Market.us)
              FormInput(
                label: '거래 당시 환율 (KRW/USD)',
                controller: _rate,
                numeric: true,
                enabled: !_busy && canWrite,
                validator: validateAmount,
              ),
            Row(
              children: [
                Expanded(
                  child: FormInput(
                    label: '날짜',
                    controller: _dateText,
                    readOnly: true,
                    enabled: !_busy && canWrite,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date.isAfter(now)
                            ? now
                            : _date.isBefore(DateTime(1900))
                            ? DateTime(1900)
                            : _date,
                        firstDate: DateTime(1900),
                        lastDate: now,
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _date = picked;
                          _updateDateTexts();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormInput(
                    label: '시간',
                    controller: _timeText,
                    readOnly: true,
                    enabled: !_busy && canWrite,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _time = picked;
                          _updateDateTexts();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            FormInput(
              label: '메모 (선택)',
              controller: _memo,
              maxLines: 2,
              enabled: !_busy && canWrite,
            ),
            Row(
              children: [
                if (_editing) ...[
                  OutlinedButton(
                    onPressed: _busy || !canWrite ? null : _delete,
                    child: const Text('삭제'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || !canWrite || accounts.isEmpty
                        ? null
                        : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_editing ? '저장' : '거래 추가'),
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
