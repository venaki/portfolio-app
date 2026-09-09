import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';

void main() {
  late MockSheetsService factory;
  late PortfolioNotifier notifier;
  setUp(() async {
    factory = MockSheetsService(
      data: (
        transactions: [
          const Transaction(
            id: 'stock',
            date: '2026-01-01',
            account: 'Stock',
            broker: 'Broker',
            type: TransactionType.buy,
            ticker: 'XYZ',
            market: Market.us,
            name: 'Example',
            shares: 1,
            price: 100,
            currency: Currency.usd,
            exchangeRate: 1500,
          ),
        ],
        otherAssets: [
          const OtherAsset(
            id: 'savings',
            date: '2026-01-01',
            account: 'Asset only',
            name: 'Savings',
            category: AssetCategory.savings,
            value: 1000,
            currency: Currency.krw,
          ),
        ],
        quotes: [],
        exchangeRate: 1500,
        settings: const AppSettings(
          accounts: ['Stock', 'Asset only', 'Unused'],
          brokers: ['Broker'],
        ),
      ),
    );
    notifier = PortfolioNotifier(factory, enableTimer: false);
    await notifier.connect('settings-test');
  });
  tearDown(() {
    notifier.dispose();
    factory.close();
  });

  test(
    'an account referenced only by other assets cannot be removed',
    () async {
      await expectLater(
        notifier.updateSettings(
          notifier.state.settings.copyWith(accounts: ['Stock', 'Unused']),
        ),
        throwsFormatException,
      );
      final stored = await factory.forSpreadsheet('settings-test').loadAll();
      expect(stored.settings.accounts, contains('Asset only'));
      expect(notifier.state.settings.accounts, contains('Asset only'));
    },
  );
  test(
    'a broker referenced by an existing transaction cannot be removed',
    () async {
      await expectLater(
        notifier.updateSettings(notifier.state.settings.copyWith(brokers: [])),
        throwsFormatException,
      );
      expect(notifier.state.settings.brokers, ['Broker']);
    },
  );
  test(
    'unused account removal and display settings survive repository reload',
    () async {
      await notifier.updateSettings(
        notifier.state.settings.copyWith(
          accounts: ['Stock', 'Asset only'],
          refreshInterval: 900,
          accentColor: '#2563EB',
        ),
      );
      await notifier.loadAll();
      expect(notifier.state.settings.accounts, ['Stock', 'Asset only']);
      expect(notifier.state.settings.refreshInterval, 900);
      expect(notifier.state.settings.accentColor, '#2563EB');
    },
  );
  test('invalid refresh interval leaves stored settings unchanged', () async {
    await expectLater(
      notifier.updateSettings(
        notifier.state.settings.copyWith(refreshInterval: 0),
      ),
      throwsFormatException,
    );
    final stored = await factory.forSpreadsheet('settings-test').loadAll();
    expect(stored.settings.refreshInterval, 60);
    expect(notifier.state.isSaving, isFalse);
  });
}
