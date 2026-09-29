import 'package:test/test.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/other_asset.dart';
import '../../lib/models/transaction.dart';
import '../../lib/services/sheets_service.dart';
import '../src/ledger.dart';

PortfolioData data({
  List<Transaction> tx = const [],
  List<OtherAsset> assets = const [],
}) => (
  transactions: tx,
  otherAssets: assets,
  quotes: [],
  exchangeRate: 1360,
  settings: const AppSettings(accounts: ['본석'], brokers: ['토스증권']),
);
Map<String, String> buy() => {
  'account': '본석',
  'broker': '토스증권',
  'ticker': 'SPCX',
  'market': 'US',
  'type': 'buy',
  'shares': '1',
  'price': '145.86',
  'exchangeRate': '1360',
  'date': '2026-09-29',
  'time': '12:38',
};
void main() {
  test('app codecs preserve precise FX, date/time and deterministic IDs', () {
    final a = plan(data(), 'trade', 'add', buy());
    final b = plan(data(), 'trade', 'add', {
      ...buy(),
      'shares': '1.0',
      'price': '145.860',
    });
    expect(a.id, b.id);
    final tx = Transaction.fromSheetRow(a.after!);
    expect(tx.shares * tx.price * tx.exchangeRate, closeTo(198369.6, .0001));
    expect(tx.time, '12:38');
  });
  test('duplicate browser-created transaction is not re-added', () {
    final row = plan(data(), 'trade', 'add', buy()).after!;
    row[0] = 'web-id';
    row[6] = 'Space Exploration Technologies Corp';
    final p = plan(
      data(tx: [Transaction.fromSheetRow(row)]),
      'trade',
      'add',
      buy(),
    );
    expect(p.action, 'noop');
    expect(p.id, 'web-id');
  });
  test('conflicting explicit id rejected', () {
    final p = plan(data(), 'trade', 'add', {...buy(), 'id': 'order-1'});
    expect(
      () => plan(
        data(tx: [Transaction.fromSheetRow(p.after!)]),
        'trade',
        'add',
        {...buy(), 'id': 'order-1', 'price': '100'},
      ),
      throwsFormatException,
    );
  });
  test('overselling and deleting a buy needed by a sell rejected', () {
    final b = Transaction.fromSheetRow(
      plan(data(), 'trade', 'add', buy()).after!,
    );
    expect(
      () => plan(data(tx: [b]), 'trade', 'add', {
        ...buy(),
        'type': 'sell',
        'shares': '2',
      }),
      throwsFormatException,
    );
    final s = Transaction.fromSheetRow(
      plan(data(tx: [b]), 'trade', 'add', {
        ...buy(),
        'type': 'sell',
        'time': '13:00',
      }).after!,
    );
    expect(
      () => plan(data(tx: [b, s]), 'trade', 'delete', {'id': b.id}),
      throwsFormatException,
    );
  });
  test('bad numbers dates time owner and market rejected', () {
    for (final bad in [
      {'price': 'NaN'},
      {'shares': '-1'},
      {'date': '2026-02-30'},
      {'time': '24:00'},
      {'account': 'unknown'},
      {'market': 'KRX'},
    ]) {
      expect(
        () => plan(data(), 'trade', 'add', {...buy(), ...bad}),
        throwsFormatException,
      );
    }
  });
  test('partial update retains untouched fields and revises signature', () {
    final tx = Transaction.fromSheetRow(
      plan(data(), 'trade', 'add', buy()).after!,
    );
    final changed = plan(data(tx: [tx]), 'trade', 'update', {
      'id': tx.id,
      'price': '150',
    });
    expect(changed.after![8], '150.0');
    expect(changed.after![13], '12:38');
    expect(changed.before, tx.toSheetRow());
  });
  test('loan overpayment is rejected with shared asset validation', () {
    final fields = {
      'account': '본석',
      'name': '대출',
      'category': 'loan',
      'value': '100',
      'currency': 'KRW',
      'date': '2026-09-29',
      'time': '12:38',
    };
    final loan = OtherAsset.fromSheetRow(
      plan(data(), 'asset', 'add', fields).after!,
    );
    expect(
      () => plan(data(assets: [loan]), 'asset', 'add', {
        ...fields,
        'value': '-101',
        'time': '13:00',
      }),
      throwsFormatException,
    );
  });
  test('Korean tickers preserve leading zeros', () {
    final row = plan(data(), 'trade', 'add', {
      ...buy(),
      'ticker': '005930',
      'market': 'KRX',
    }).after!;
    expect(row[4], '005930');
    expect(row[9], 'KRW');
    expect(row[10], '1.0');
  });
}
