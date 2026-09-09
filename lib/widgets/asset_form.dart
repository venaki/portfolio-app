import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/other_asset.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import 'form_fields.dart';

class AssetForm extends ConsumerStatefulWidget {
  const AssetForm({
    super.key,
    this.asset,
    this.initialAccount,
    this.initialName,
    this.initialCategory,
    this.initialCurrency,
  });
  final OtherAsset? asset;
  final String? initialAccount, initialName;
  final AssetCategory? initialCategory;
  final Currency? initialCurrency;
  @override
  ConsumerState<AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<AssetForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _value = TextEditingController(),
      _memo = TextEditingController();
  final _dateText = TextEditingController(),
      _timeText = TextEditingController();
  late String _account;
  late AssetCategory _category;
  late Currency _currency;
  late DateTime _date;
  late TimeOfDay _time;
  bool _positive = true, _busy = false;
  String? _error;
  bool get _editing => widget.asset != null;
  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _account =
        asset?.account ??
        widget.initialAccount ??
        ref.read(portfolioProvider).settings.accounts.firstOrNull ??
        '';
    _category =
        asset?.category ?? widget.initialCategory ?? AssetCategory.savings;
    _currency = asset?.currency ?? widget.initialCurrency ?? Currency.krw;
    _name.text = asset?.name ?? widget.initialName ?? '';
    _value.text = asset?.value.abs().toString() ?? '';
    _memo.text = asset?.memo ?? '';
    _positive = (asset?.value ?? 0) >= 0;
    _date = DateTime.tryParse(asset?.date ?? '') ?? DateTime.now();
    final parts = (asset?.time ?? '').split(':');
    _time = TimeOfDay(
      hour: (int.tryParse(parts.first) ?? TimeOfDay.now().hour).clamp(0, 23),
      minute:
          (int.tryParse(parts.length > 1 ? parts[1] : '') ??
                  TimeOfDay.now().minute)
              .clamp(0, 59),
    );
    _updateDates();
  }

  void _updateDates() {
    _dateText.text = _date.toIso8601String().substring(0, 10);
    _timeText.text =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final controller in [_name, _value, _memo, _dateText, _timeText]) {
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
      final value = parseAmount(_value.text)!;
      final asset = OtherAsset(
        id: widget.asset?.id ?? const Uuid().v4(),
        account: _account,
        name: _name.text.trim(),
        category: _category,
        currency: _currency,
        value: _positive ? value : -value,
        date: _dateText.text,
        time: _timeText.text,
        memo: _memo.text.trim(),
      );
      final notifier = ref.read(portfolioProvider.notifier);
      if (_editing) {
        await notifier.updateOtherAsset(asset);
      } else {
        await notifier.addOtherAsset(asset);
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
    if (_busy || !await confirmDelete(context, '자산 내역 삭제') || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(portfolioProvider.notifier)
          .deleteOtherAsset(widget.asset!.id);
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
    return RecordFormDialog(
      title: _editing ? '자산 내역 수정' : '자산 내역 추가',
      busy: _busy,
      onClose: () => Navigator.pop(context),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              label: '명의',
              options: {for (final account in accounts) account: account},
              value: _account,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _account = value),
            ),
            FormChoices(
              label: '자산 유형',
              options: {
                for (final category in AssetCategory.values)
                  category: category.label,
              },
              value: _category,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _category = value),
            ),
            FormChoices(
              label: '내역 유형',
              options: {
                true: _category.positiveLabel,
                false: _category.negativeLabel,
              },
              value: _positive,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _positive = value),
            ),
            FormInput(
              label: '자산명',
              controller: _name,
              enabled: !_busy && canWrite,
              validator: validateRequiredText,
            ),
            FormInput(
              label: '금액',
              controller: _value,
              numeric: true,
              enabled: !_busy && canWrite,
              validator: validateAmount,
            ),
            FormChoices(
              label: '통화',
              options: const {Currency.krw: 'KRW', Currency.usd: 'USD'},
              value: _currency,
              enabled: !_busy && canWrite,
              onChanged: (value) => setState(() => _currency = value),
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
                          _updateDates();
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
                          _updateDates();
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
                        : Text(_editing ? '저장' : '추가'),
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
