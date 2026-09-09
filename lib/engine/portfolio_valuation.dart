import '../models/holding.dart';
import '../models/other_asset.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import 'calculations.dart';

/// Daily change means the price movement of current holdings, translated at the
/// current FX rate. Other assets are included in the denominator consistently.
/// It does not claim to measure cash-flow-adjusted investment performance.
class ValuationTotals {
  final double valueKRW;
  final double costKRW;
  final double dailyChangeKRW;
  final double yestValueKRW;
  final double usValueKRW;
  final double krValueKRW;
  final double otherValueKRW;

  const ValuationTotals({
    this.valueKRW = 0,
    this.costKRW = 0,
    this.dailyChangeKRW = 0,
    this.yestValueKRW = 0,
    this.usValueKRW = 0,
    this.krValueKRW = 0,
    this.otherValueKRW = 0,
  });

  double get profitKRW => valueKRW - costKRW;
  double get profitPct => costKRW > 0 ? profitKRW / costKRW * 100 : 0;
  double get dailyChangePct =>
      yestValueKRW > 0 ? dailyChangeKRW / yestValueKRW * 100 : 0;

  ValuationTotals operator +(ValuationTotals other) => ValuationTotals(
    valueKRW: valueKRW + other.valueKRW,
    costKRW: costKRW + other.costKRW,
    dailyChangeKRW: dailyChangeKRW + other.dailyChangeKRW,
    yestValueKRW: yestValueKRW + other.yestValueKRW,
    usValueKRW: usValueKRW + other.usValueKRW,
    krValueKRW: krValueKRW + other.krValueKRW,
    otherValueKRW: otherValueKRW + other.otherValueKRW,
  );
}

class HoldingValuation {
  final Holding holding;
  final StockQuote? quote;
  final double? valueKRW;
  final double costKRW;
  final double? dailyChangeKRW;
  final double? yestValueKRW;

  const HoldingValuation({
    required this.holding,
    required this.quote,
    required this.valueKRW,
    required this.costKRW,
    required this.dailyChangeKRW,
    required this.yestValueKRW,
  });

  bool get hasPrice => valueKRW != null;
  double? get profitKRW => valueKRW == null ? null : valueKRW! - costKRW;
  double? get profitPct =>
      profitKRW == null ? null : (costKRW > 0 ? profitKRW! / costKRW * 100 : 0);
}

class OtherAssetValuation {
  final ConsolidatedAsset asset;
  final double? valueKRW;

  const OtherAssetValuation({required this.asset, required this.valueKRW});
}

class PortfolioValuation {
  final ValuationTotals total;
  final Map<String, ValuationTotals> byAccount;
  final List<HoldingValuation> positions;
  final List<OtherAssetValuation> assets;
  final List<String> issues;
  final bool isComplete;
  final bool isDailyComplete;

  const PortfolioValuation({
    required this.total,
    required this.byAccount,
    required this.positions,
    required this.assets,
    required this.issues,
    required this.isComplete,
    required this.isDailyComplete,
  });
}

PortfolioValuation evaluatePortfolio({
  required List<Holding> holdings,
  required List<ConsolidatedAsset> otherAssets,
  required Map<String, StockQuote> quotes,
  required double exchangeRate,
}) {
  var total = const ValuationTotals();
  final accounts = <String, ValuationTotals>{};
  final positions = <HoldingValuation>[];
  final assets = <OtherAssetValuation>[];
  final issues = <String>[];
  var complete = true;
  var dailyComplete = true;
  final validFX = exchangeRate.isFinite && exchangeRate > 0;

  void add(String account, ValuationTotals value) {
    total = total + value;
    accounts[account] = (accounts[account] ?? const ValuationTotals()) + value;
  }

  for (final holding in holdings) {
    if (holding.shares == 0) continue;
    final quote = quotes[holding.ticker];
    final expectedCurrency = holding.currency == Currency.usd ? 'USD' : 'KRW';
    final hasRate = holding.currency == Currency.krw || validFX;
    final validHolding =
        holding.shares.isFinite &&
        holding.shares > 0 &&
        holding.costKRW.isFinite &&
        holding.costKRW >= 0;
    final hasPrice =
        validHolding &&
        hasRate &&
        quote != null &&
        quote.hasValidPrice &&
        quote.currency == expectedCurrency;
    double? value;
    if (hasPrice) {
      final candidate = calcTotalValueKRW(holding, quote.price, exchangeRate);
      if (candidate.isFinite) value = candidate;
    }
    if (value == null) {
      complete = false;
      dailyComplete = false;
      issues.add('${holding.ticker}: 시세·환율 또는 보유정보를 확인할 수 없습니다.');
    } else if (quote!.isStale) {
      complete = false;
      dailyComplete = false;
      issues.add('${holding.ticker}: 이전에 확인한 시세를 표시합니다.');
    }

    double? daily;
    double? yesterday;
    if (value != null && quote!.hasPreviousClose && !quote.isStale) {
      final candidate = calcTotalValueKRW(
        holding,
        quote.closeYest,
        exchangeRate,
      );
      if (candidate.isFinite) {
        yesterday = candidate;
        daily = value - candidate;
      }
    }
    if (yesterday == null) {
      dailyComplete = false;
      if (value != null && !quote!.isStale) {
        issues.add('${holding.ticker}: 전일 종가를 확인할 수 없습니다.');
      }
    }
    final cost = validHolding ? holding.costKRW : 0.0;
    positions.add(
      HoldingValuation(
        holding: holding,
        quote: quote,
        valueKRW: value,
        costKRW: cost,
        dailyChangeKRW: daily,
        yestValueKRW: yesterday,
      ),
    );
    add(
      holding.account,
      ValuationTotals(
        valueKRW: value ?? 0,
        costKRW: cost,
        dailyChangeKRW: daily ?? 0,
        yestValueKRW: yesterday ?? 0,
        usValueKRW: holding.market == Market.us ? value ?? 0 : 0,
        krValueKRW: holding.market != Market.us ? value ?? 0 : 0,
      ),
    );
  }

  for (final asset in otherAssets) {
    double? value;
    final invalidLoan =
        asset.category == AssetCategory.loan && asset.totalValue < 0;
    if (asset.totalValue.isFinite &&
        !invalidLoan &&
        (asset.currency == Currency.krw || validFX)) {
      final candidate =
          asset.signedValue *
          (asset.currency == Currency.krw ? 1 : exchangeRate);
      if (candidate.isFinite) value = candidate;
    }
    if (value == null) {
      complete = false;
      dailyComplete = false;
      issues.add('${asset.name}: 자산 잔액 또는 환율이 올바르지 않습니다.');
    }
    assets.add(OtherAssetValuation(asset: asset, valueKRW: value));
    // Other assets retain the existing valuation-as-cost policy. The UI labels
    // stock unrealized P/L explicitly rather than implying total investment P/L.
    add(
      asset.account,
      ValuationTotals(
        valueKRW: value ?? 0,
        costKRW: value ?? 0,
        yestValueKRW: value ?? 0,
        otherValueKRW: value ?? 0,
      ),
    );
  }
  if (![
    total.valueKRW,
    total.costKRW,
    total.dailyChangeKRW,
    total.yestValueKRW,
  ].every((value) => value.isFinite)) {
    complete = false;
    dailyComplete = false;
    issues.add('평가 합계가 계산 범위를 초과합니다.');
  }
  return PortfolioValuation(
    total: total,
    byAccount: Map.unmodifiable(accounts),
    positions: List.unmodifiable(positions),
    assets: List.unmodifiable(assets),
    issues: List.unmodifiable(issues),
    isComplete: complete,
    isDailyComplete: complete && dailyComplete,
  );
}
