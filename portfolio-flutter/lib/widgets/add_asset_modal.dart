import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/other_asset.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';

/// Shows the add-asset dialog.
Future<void> showAddAssetDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const Center(child: AddAssetModal()),
  );
}

class AddAssetModal extends ConsumerStatefulWidget {
  const AddAssetModal({super.key});

  @override
  ConsumerState<AddAssetModal> createState() => _AddAssetModalState();
}

class _AddAssetModalState extends ConsumerState<AddAssetModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _memoController = TextEditingController();

  String _account = '';
  AssetCategory _category = AssetCategory.savings;
  Currency _currency = Currency.krw;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final accounts = ref.read(portfolioProvider).settings.accounts;
    if (accounts.isNotEmpty) _account = accounts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_account.isEmpty) return;

    setState(() => _isSaving = true);

    final asset = OtherAsset(
      id: const Uuid().v4(),
      account: _account,
      name: _nameController.text.trim(),
      category: _category,
      value: double.tryParse(_valueController.text) ?? 0,
      currency: _currency,
      date: DateTime.now().toIso8601String().substring(0, 10),
      memo: _memoController.text.trim(),
    );

    try {
      await ref.read(portfolioProvider.notifier).addOtherAsset(asset);
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
                      '자산 추가',
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

                // 자산유형
                _buildLabel('자산유형'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('예금',
                        isActive: _category == AssetCategory.savings,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _category = AssetCategory.savings)),
                    _buildChip('채권',
                        isActive: _category == AssetCategory.bond,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _category = AssetCategory.bond)),
                    _buildChip('대출',
                        isActive: _category == AssetCategory.loan,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _category = AssetCategory.loan)),
                    _buildChip('기타',
                        isActive: _category == AssetCategory.other,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _category = AssetCategory.other)),
                  ],
                ),
                const SizedBox(height: 16),

                // 자산명
                _buildLabel('자산명'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _nameController,
                  validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),

                // 금액
                _buildLabel('금액'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 16),

                // 통화
                _buildLabel('통화'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildChip('KRW',
                        isActive: _currency == Currency.krw,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _currency = Currency.krw)),
                    const SizedBox(width: 8),
                    _buildChip('USD',
                        isActive: _currency == Currency.usd,
                        accentColor: accentColor,
                        onTap: () =>
                            setState(() => _currency = Currency.usd)),
                  ],
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
                              '추가',
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
