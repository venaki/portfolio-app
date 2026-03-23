import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/other_asset.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';

/// Shows the edit-asset dialog.
Future<void> showEditAssetDialog(BuildContext context, OtherAsset asset) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Center(child: EditAssetModal(asset: asset)),
  );
}

class EditAssetModal extends ConsumerStatefulWidget {
  final OtherAsset asset;
  const EditAssetModal({super.key, required this.asset});

  @override
  ConsumerState<EditAssetModal> createState() => _EditAssetModalState();
}

class _EditAssetModalState extends ConsumerState<EditAssetModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _memoController = TextEditingController();

  late String _account;
  late AssetCategory _category;
  late Currency _currency;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _account = a.account;
    _category = a.category;
    _currency = a.currency;
    _nameController.text = a.name;
    _valueController.text = a.value.toString();
    _memoController.text = a.memo;
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

    setState(() => _isSaving = true);

    final asset = OtherAsset(
      id: widget.asset.id,
      account: _account,
      name: _nameController.text.trim(),
      category: _category,
      value: double.tryParse(_valueController.text) ?? 0,
      currency: _currency,
      date: widget.asset.date,
      memo: _memoController.text.trim(),
    );

    try {
      await ref.read(portfolioProvider.notifier).updateOtherAsset(asset);
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

  Future<void> _delete() async {
    try {
      await ref
          .read(portfolioProvider.notifier)
          .deleteOtherAsset(widget.asset.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(portfolioProvider).settings.accounts;

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
                      '자산 편집',
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
                        onTap: () =>
                            setState(() => _category = AssetCategory.savings)),
                    _buildChip('채권',
                        isActive: _category == AssetCategory.bond,
                        onTap: () =>
                            setState(() => _category = AssetCategory.bond)),
                    _buildChip('대출',
                        isActive: _category == AssetCategory.loan,
                        onTap: () =>
                            setState(() => _category = AssetCategory.loan)),
                    _buildChip('기타',
                        isActive: _category == AssetCategory.other,
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
                ),
                const SizedBox(height: 16),

                // 금액
                _buildLabel('금액'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                ),
                const SizedBox(height: 16),

                // 통화
                _buildLabel('통화'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildChip('KRW',
                        isActive: _currency == Currency.krw,
                        onTap: () =>
                            setState(() => _currency = Currency.krw)),
                    const SizedBox(width: 8),
                    _buildChip('USD',
                        isActive: _currency == Currency.usd,
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
                ),
                const SizedBox(height: 24),

                // Bottom buttons: 삭제 + 저장
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _delete,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE07B54),
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
                            color: const Color(0xFF0D6E6E),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0D6E6E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF0D6E6E) : const Color(0xFFE5E5E5),
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
    );
  }
}
