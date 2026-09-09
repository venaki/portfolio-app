import '../models/transaction.dart';
import '../models/sheet_schema.dart';

String encodeTransactionCsv(List<Transaction> transactions) {
  String escape(String value, {bool numeric = false}) {
    var safe = value;
    if (!numeric && RegExp(r'^[\s]*[=+\-@]').hasMatch(safe)) safe = "'$safe";
    return '"${safe.replaceAll('"', '""')}"';
  }

  return '\uFEFF${SheetSchema.transactions.join(',')}\r\n${transactions.map((transaction) => transaction.toSheetRow().indexed.map((entry) => escape(entry.$2, numeric: const {7, 8, 10}.contains(entry.$1))).join(',')).join('\r\n')}';
}
