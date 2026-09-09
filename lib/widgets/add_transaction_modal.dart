import 'package:flutter/material.dart';
import 'transaction_form.dart';

Future<void> showAddTransactionDialog(BuildContext context) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => AddTransactionModal(),
);

class AddTransactionModal extends StatelessWidget {
  const AddTransactionModal({super.key});
  @override
  Widget build(BuildContext context) => TransactionForm();
}
