import 'package:flutter/material.dart';
import '../models/other_asset.dart';
import 'asset_form.dart';

Future<void> showEditAssetDialog(BuildContext context, OtherAsset asset) =>
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditAssetModal(asset: asset),
    );

class EditAssetModal extends StatelessWidget {
  const EditAssetModal({super.key, required this.asset});
  final OtherAsset asset;
  @override
  Widget build(BuildContext context) => AssetForm(asset: asset);
}
