import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';

/// Dev 모드용 더미 데이터
class MockData {
  static const exchangeRate = 1380.0;

  static const settings = AppSettings(
    accounts: ['철수', '영희'],
    brokers: ['토스증권', '나무증권'],
    baseCurrency: 'KRW',
    accentColor: '#0D6E6E',
    refreshInterval: 60,
    version: 1,
  );

  // ─── 거래내역 ───

  static const transactions = <Transaction>[
    // ── 미국주식 ──

    // AAPL: 상승 종목 (매수만)
    Transaction(
      id: 'tx-001', date: '2025-06-15', account: '철수',
      type: TransactionType.buy, ticker: 'AAPL', market: Market.us,
      name: 'Apple Inc.', shares: 10, price: 155.0,
      currency: Currency.usd, exchangeRate: 1320.0, broker: '토스증권',
    ),
    Transaction(
      id: 'tx-002', date: '2025-09-20', account: '철수',
      type: TransactionType.buy, ticker: 'AAPL', market: Market.us,
      name: 'Apple Inc.', shares: 5, price: 170.0,
      currency: Currency.usd, exchangeRate: 1350.0, broker: '토스증권',
    ),

    // TSLA: 하락 종목 (매수만)
    Transaction(
      id: 'tx-003', date: '2025-07-10', account: '철수',
      type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
      name: 'Tesla, Inc.', shares: 8, price: 280.0,
      currency: Currency.usd, exchangeRate: 1330.0, broker: '나무증권',
    ),

    // NVDA: 매수 + 매도 혼합
    Transaction(
      id: 'tx-004', date: '2025-05-01', account: '영희',
      type: TransactionType.buy, ticker: 'NVDA', market: Market.us,
      name: 'NVIDIA Corporation', shares: 20, price: 90.0,
      currency: Currency.usd, exchangeRate: 1300.0, broker: '나무증권',
    ),
    Transaction(
      id: 'tx-005', date: '2025-11-15', account: '영희',
      type: TransactionType.sell, ticker: 'NVDA', market: Market.us,
      name: 'NVIDIA Corporation', shares: 10, price: 140.0,
      currency: Currency.usd, exchangeRate: 1370.0, broker: '나무증권',
    ),

    // ── 한국주식 ──

    // 삼성전자: 상승 종목 (매수만)
    Transaction(
      id: 'tx-006', date: '2025-06-01', account: '철수',
      type: TransactionType.buy, ticker: '005930', market: Market.krx,
      name: '삼성전자', shares: 50, price: 65000.0,
      currency: Currency.krw, exchangeRate: 1.0, broker: '토스증권',
    ),
    Transaction(
      id: 'tx-007', date: '2025-10-05', account: '철수',
      type: TransactionType.buy, ticker: '005930', market: Market.krx,
      name: '삼성전자', shares: 30, price: 68000.0,
      currency: Currency.krw, exchangeRate: 1.0, broker: '토스증권',
    ),

    // 카카오: 하락 종목 (매수만)
    Transaction(
      id: 'tx-008', date: '2025-08-20', account: '영희',
      type: TransactionType.buy, ticker: '035720', market: Market.kosdaq,
      name: '카카오', shares: 100, price: 55000.0,
      currency: Currency.krw, exchangeRate: 1.0, broker: '나무증권',
    ),

    // SK하이닉스: 매수 + 매도 혼합
    Transaction(
      id: 'tx-009', date: '2025-04-10', account: '철수',
      type: TransactionType.buy, ticker: '000660', market: Market.krx,
      name: 'SK하이닉스', shares: 40, price: 150000.0,
      currency: Currency.krw, exchangeRate: 1.0, broker: '토스증권',
    ),
    Transaction(
      id: 'tx-010', date: '2025-12-01', account: '철수',
      type: TransactionType.sell, ticker: '000660', market: Market.krx,
      name: 'SK하이닉스', shares: 15, price: 185000.0,
      currency: Currency.krw, exchangeRate: 1.0, broker: '토스증권',
    ),
  ];

  // ─── 시세 ───

  static const quotes = <StockQuote>[
    // 미국주식
    StockQuote(
      ticker: 'AAPL', name: 'Apple Inc.',
      price: 192.50, changePct: 1.35, closeYest: 189.93, currency: 'USD',
    ),
    StockQuote(
      ticker: 'TSLA', name: 'Tesla, Inc.',
      price: 245.80, changePct: -2.10, closeYest: 251.07, currency: 'USD',
    ),
    StockQuote(
      ticker: 'NVDA', name: 'NVIDIA Corporation',
      price: 148.30, changePct: 0.85, closeYest: 147.05, currency: 'USD',
    ),
    // 한국주식
    StockQuote(
      ticker: '005930', name: '삼성전자',
      price: 72000, changePct: 1.55, closeYest: 70900, currency: 'KRW',
    ),
    StockQuote(
      ticker: '035720', name: '카카오',
      price: 42500, changePct: -3.20, closeYest: 43900, currency: 'KRW',
    ),
    StockQuote(
      ticker: '000660', name: 'SK하이닉스',
      price: 192000, changePct: 2.13, closeYest: 188000, currency: 'KRW',
    ),
  ];

  // ─── 기타자산 ───

  static const otherAssets = <OtherAsset>[
    OtherAsset(
      id: 'oa-001', account: '철수', name: '토스뱅크 정기예금',
      category: AssetCategory.savings, value: 30000000,
      currency: Currency.krw, date: '2025-01-15', memo: '연 3.5%, 2026-01 만기',
    ),
    OtherAsset(
      id: 'oa-002', account: '영희', name: '국고채 10년물',
      category: AssetCategory.bond, value: 10000000,
      currency: Currency.krw, date: '2025-03-01', memo: '연 3.2%',
    ),
    OtherAsset(
      id: 'oa-003', account: '철수', name: '신용대출',
      category: AssetCategory.loan, value: -15000000,
      currency: Currency.krw, date: '2025-06-01', memo: '연 4.5%',
    ),
    OtherAsset(
      id: 'oa-004', account: '영희', name: 'USD 현금',
      category: AssetCategory.savings, value: 5000,
      currency: Currency.usd, date: '2025-09-10',
    ),
    OtherAsset(
      id: 'oa-005', account: '철수', name: '비트코인 (참고용)',
      category: AssetCategory.other, value: 2500000,
      currency: Currency.krw, date: '2025-11-20', memo: '0.03 BTC',
    ),
  ];
}
