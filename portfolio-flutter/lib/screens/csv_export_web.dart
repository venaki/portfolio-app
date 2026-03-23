// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/transaction.dart';

void downloadCsv(List<Transaction> transactions) {
  const bom = '\uFEFF';
  const header = 'id,date,account,type,ticker,market,name,shares,price,currency,exchangeRate,memo';
  final rows = transactions.map((tx) {
    final row = tx.toSheetRow();
    // Escape fields containing commas or quotes
    return row.map((field) {
      if (field.contains(',') || field.contains('"') || field.contains('\n')) {
        return '"${field.replaceAll('"', '""')}"';
      }
      return field;
    }).join(',');
  }).join('\n');

  final csv = '$bom$header\n$rows';
  final blob = html.Blob([csv], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final dateStr =
      DateTime.now().toString().substring(0, 10).replaceAll('-', '');
  html.AnchorElement(href: url)
    ..setAttribute('download', 'portfolio_$dateStr.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
