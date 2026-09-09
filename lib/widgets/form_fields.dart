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

const recordLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Color(0xFF1A1A1A),
);

InputDecoration recordInputDecoration(BuildContext context, {String? hint}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
    );

ButtonStyle recordButtonStyle(
  BuildContext context, {
  bool destructive = false,
}) => FilledButton.styleFrom(
  backgroundColor: destructive
      ? const Color(0xFFD32F2F)
      : Theme.of(context).colorScheme.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 48),
  padding: const EdgeInsets.all(15),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  side: BorderSide.none,
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

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
    this.showLabel = true,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool numeric, readOnly, enabled, showLabel;
  final int maxLines;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(label, style: recordLabelStyle),
          const SizedBox(height: 6),
        ],
        Semantics(
          label: label,
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            decoration: recordInputDecoration(context),
          ),
        ),
      ],
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
    this.colors = const {},
  });
  final String label;
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Map<T, Color> colors;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: recordLabelStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final selected = entry.key == value;
            final accent =
                colors[entry.key] ?? Theme.of(context).colorScheme.primary;
            return Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: enabled ? () => onChanged(entry.key) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? accent : const Color(0xFFE5E5E5),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '삭제한 내역은 자동으로 복구되지 않습니다. 삭제하시겠습니까?',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                    color: const Color(0xFF888888),
                    onPressed: busy ? null : onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
