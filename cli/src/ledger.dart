import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../lib/engine/holdings_engine.dart';
import '../../lib/models/other_asset.dart';
import '../../lib/models/transaction.dart';
import '../../lib/services/sheets_service.dart';

String digest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
Map<String, String> record(List<String> keys, List<String> row) =>
    Map.fromIterables(keys, row);

class Change {
  final String collection, action, id, revision;
  final List<String>? before, after;
  Change(
    this.collection,
    this.action,
    this.id,
    this.before,
    this.after,
    this.revision,
  );
  Map<String, dynamic> toJson() => {
    'collection': collection,
    'action': action,
    'id': id,
    'before': before,
    'after': after,
    'revision': revision,
  };
}

String revisionOf(PortfolioData data) => digest({
  'transactions': data.transactions.map((x) => x.toSheetRow()).toList(),
  'assets': data.otherAssets.map((x) => x.toSheetRow()).toList(),
  'accounts': data.settings.accounts,
  'brokers': data.settings.brokers,
});

Change plan(
  PortfolioData data,
  String collection,
  String action,
  Map<String, String> fields,
) {
  final trade = collection == 'trade';
  final headers = trade ? Transaction.sheetHeaders : OtherAsset.sheetHeaders;
  final rows = trade
      ? data.transactions.map((x) => x.toSheetRow()).toList()
      : data.otherAssets.map((x) => x.toSheetRow()).toList();
  List<String>? before;
  var id = fields['id'];
  if (action != 'add') {
    final matches = rows.where((r) => r.first == id).toList();
    if (id == null || matches.length != 1)
      throw FormatException('고유한 --id가 필요합니다.');
    before = matches.single;
  }
  List<String>? after;
  if (action != 'delete') {
    final values = before == null
        ? <String, String>{}
        : record(headers, before);
    values.addAll(fields);
    values.putIfAbsent('memo', () => '');
    if (trade) {
      values.putIfAbsent('name', () => values['ticker'] ?? '');
      values.putIfAbsent(
        'currency',
        () => values['market'] == 'US' ? 'USD' : 'KRW',
      );
      if (values['currency'] == 'KRW')
        values.putIfAbsent('exchangeRate', () => '1');
    }
    for (final key in headers.where((k) => k != 'id')) {
      if (!values.containsKey(key)) throw FormatException('필수 필드: $key');
    }
    values['id'] =
        id ??
        'cli-${digest([collection, for (final k in headers.skip(1)) values[k]]).substring(0, 32)}';
    after = headers.map((k) => values[k]!).toList();
    // Canonicalize numbers, ticker and legacy defaults with the app codec.
    after = trade
        ? Transaction.fromSheetRow(after).toSheetRow()
        : OtherAsset.fromSheetRow(after).toSheetRow();
    if (id == null)
      after[0] =
          'cli-${digest([collection, ...after.skip(1)]).substring(0, 32)}';
    if (action == 'add' && fields['id'] == null) {
      final indexes = trade
          ? [1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13]
          : [1, 2, 3, 4, 5, 6, 8];
      final same = rows
          .where(
            (r) =>
                digest([for (final i in indexes) r[i]]) ==
                digest([for (final i in indexes) after![i]]),
          )
          .toList();
      if (same.isNotEmpty)
        return Change(
          collection,
          'noop',
          same.first.first,
          same.first,
          same.first,
          revisionOf(data),
        );
    }
    id = after.first;
    final existing = rows.where((r) => r.first == id).toList();
    if (action == 'add' && existing.isNotEmpty) {
      if (existing.length == 1 && digest(existing.single) == digest(after)) {
        return Change(
          collection,
          'noop',
          id,
          existing.single,
          after,
          revisionOf(data),
        );
      }
      throw FormatException('동일 ID의 다른 기록이 있습니다.');
    }
    final account = after[trade ? 2 : 1];
    if (!data.settings.accounts.contains(account))
      throw FormatException('등록되지 않은 명의: $account');
    if (trade && !data.settings.brokers.contains(after[12]))
      throw FormatException('등록되지 않은 증권사');
  }
  final next = rows
      .map((r) => r.first == id ? after : r)
      .whereType<List<String>>()
      .toList();
  if (action == 'add') next.add(after!);
  final errors = trade
      ? replayPortfolio(next.map(Transaction.fromSheetRow).toList()).issues
      : validateOtherAssetLedger(next.map(OtherAsset.fromSheetRow).toList());
  if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  return Change(collection, action, id!, before, after, revisionOf(data));
}

Future<void> applyChange(SheetsService repo, Change change) async {
  if (change.action == 'noop') return;
  final fresh = await repo.loadAll();
  if (repo.dataIssues.isNotEmpty || revisionOf(fresh) != change.revision) {
    throw StateError('원장이 변경되었습니다. 다시 조회하고 미리보기를 실행하세요.');
  }
  final dates = [
    if (change.before != null)
      change.before![change.collection == 'trade' ? 1 : 6],
    if (change.after != null)
      change.after![change.collection == 'trade' ? 1 : 6],
    if (repo.historyDirtyFrom != null) repo.historyDirtyFrom!,
  ]..sort();
  // Mark before mutation: a partial failure can over-invalidate, never leave stale history trusted.
  await repo.setHistoryDirtyFrom(dates.first);
  if (change.collection == 'trade') {
    if (change.action == 'delete') {
      await repo.deleteTransaction(change.id);
    } else {
      final tx = Transaction.fromSheetRow(change.after!);
      await repo.addPriceRow(
        tx.ticker,
        tx.market.toSheetValue(),
        tx.currency.name.toUpperCase(),
      );
      if (change.action == 'add') {
        await repo.addTransaction(tx);
      } else {
        await repo.updateTransaction(tx);
      }
    }
  } else {
    if (change.action == 'delete') {
      await repo.deleteOtherAsset(change.id);
    } else if (change.action == 'add') {
      await repo.addOtherAsset(OtherAsset.fromSheetRow(change.after!));
    } else {
      await repo.updateOtherAsset(OtherAsset.fromSheetRow(change.after!));
    }
  }
  final saved = await repo.loadAll();
  final rows = change.collection == 'trade'
      ? saved.transactions.map((x) => x.toSheetRow())
      : saved.otherAssets.map((x) => x.toSheetRow());
  final matches = rows.where((r) => r.first == change.id).toList();
  if (change.after == null
      ? matches.isNotEmpty
      : matches.length != 1 ||
            digest(matches.single) != digest(change.after!)) {
    throw StateError('저장 결과가 불확실합니다. ID로 조회한 뒤 재시도하세요.');
  }
}
