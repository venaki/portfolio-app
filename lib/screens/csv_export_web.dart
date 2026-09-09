import '../models/transaction.dart';
import '../services/file_transfer.dart';
import 'csv_export.dart';

void downloadCsv(List<Transaction> transactions) => downloadText(
  text: encodeTransactionCsv(transactions),
  fileName:
      'portfolio-transactions-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
  mimeType: 'text/csv;charset=utf-8',
);
