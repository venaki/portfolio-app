import 'package:flutter/material.dart';

double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', ''));

String? validateAmount(String? text, {bool required = true}) {
  if (text == null || text.trim().isEmpty) {
    return required ? '금액을 입력해주세요' : null;
  }
  final value = parseAmount(text);
  if (value == null || !value.isFinite) return '올바른 숫자를 입력해주세요';
  if (value <= 0) return '0보다 큰 값을 입력해주세요';
  return null;
}

String? validateRequiredText(String? value) =>
    value == null || value.trim().isEmpty ? '필수 항목입니다' : null;

class FormInput extends StatelessWidget {
  const FormInput({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.numeric = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool numeric, readOnly, enabled;
  final int maxLines;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class FormChoices<T> extends StatelessWidget {
  const FormChoices({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.entries
              .map(
                (entry) => ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == value,
                  onSelected: enabled ? (_) => onChanged(entry.key) : null,
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('삭제한 내역은 자동으로 복구되지 않습니다. 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    ) ??
    false;

class RecordFormDialog extends StatelessWidget {
  const RecordFormDialog({
    super.key,
    required this.title,
    required this.busy,
    required this.onClose,
    required this.child,
  });
  final String title;
  final bool busy;
  final VoidCallback onClose;
  final Widget child;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: busy ? null : onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
