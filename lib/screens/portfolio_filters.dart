import '../models/transaction.dart';
import '../models/other_asset.dart';

List<String> mergeHoldingOrder(
  List<String> currentOrder,
  List<String> allKeys,
  List<String> reorderedSubset,
) {
  final available = allKeys.toSet();
  final base = <String>{
    ...currentOrder.where(available.contains),
    ...allKeys,
  }.toList();
  final subset = reorderedSubset.where(available.contains).toSet();
  final replacements = reorderedSubset
      .where(available.contains)
      .toList()
      .iterator;
  return base
      .map(
        (key) => subset.contains(key) && replacements.moveNext()
            ? replacements.current
            : key,
      )
      .toList();
}

List<Transaction> filterTransactions(
  List<Transaction> transactions, {
  String market = '전체',
  String account = '전체',
  String type = '전체',
  String broker = '전체',
  String query = '',
  DateTime? from,
  DateTime? to,
}) {
  if (type == '기타자산' || market == '기타') return [];
  final search = query.trim().toLowerCase();
  return transactions.where((tx) {
    if (market == '미국' && tx.market != Market.us) return false;
    if (market == '한국' && tx.market == Market.us) return false;
    if (account != '전체' && tx.account != account) return false;
    if (broker != '전체' && tx.broker != broker) return false;
    if (type == '매수' && tx.type != TransactionType.buy) return false;
    if (type == '매도' && tx.type != TransactionType.sell) return false;
    if (type == '잔고 조정' &&
        tx.type != TransactionType.adjustment &&
        tx.type != TransactionType.openingBalance) {
      return false;
    }
    if (search.isNotEmpty &&
        !'${tx.ticker} ${tx.name} ${tx.memo}'.toLowerCase().contains(search)) {
      return false;
    }
    final date = DateTime.tryParse(tx.date);
    if (from != null && (date == null || date.isBefore(from))) return false;
    if (to != null && (date == null || date.isAfter(to))) return false;
    return true;
  }).toList();
}

List<OtherAsset> filterAssets(
  List<OtherAsset> assets, {
  String market = '전체',
  String account = '전체',
  String type = '전체',
  String broker = '전체',
  String query = '',
  DateTime? from,
  DateTime? to,
}) {
  if (type != '전체' && type != '기타자산' ||
      market == '미국' ||
      market == '한국' ||
      broker != '전체') {
    return [];
  }
  final search = query.trim().toLowerCase();
  return assets.where((asset) {
    if (account != '전체' && asset.account != account) return false;
    if (search.isNotEmpty &&
        !'${asset.name} ${asset.memo}'.toLowerCase().contains(search)) {
      return false;
    }
    final date = DateTime.tryParse(asset.date);
    if (from != null && (date == null || date.isBefore(from))) return false;
    if (to != null && (date == null || date.isAfter(to))) return false;
    return true;
  }).toList();
}
