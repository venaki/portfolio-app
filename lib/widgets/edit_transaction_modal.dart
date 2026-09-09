import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'transaction_form.dart';

Future<void> showEditTransactionDialog(
  BuildContext context,
  Transaction transaction,
) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => EditTransactionModal(transaction: transaction),
);

class EditTransactionModal extends StatelessWidget {
  const EditTransactionModal({super.key, required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext context) =>
      TransactionForm(transaction: transaction);
}
