import 'package:flutter/material.dart';
import 'asset_form.dart';

Future<void> showAddAssetDialog(BuildContext context) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => AddAssetModal(),
);

class AddAssetModal extends StatelessWidget {
  const AddAssetModal({super.key});
  @override
  Widget build(BuildContext context) => AssetForm();
}
